#!/opt/pypy/bin/pypy

import decimal
import json
import logging
import os
import site
import sys
import time
from typing import Any, Dict, Optional, Tuple, Union
import urllib.request as request

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Constants
RUNTIME_API_ENDPOINT = "2018-06-01/runtime"
HANDLER = os.getenv("_HANDLER")
RUNTIME_API = os.getenv("AWS_LAMBDA_RUNTIME_API")

# Add PyPy paths to sys.path
for path in ["/opt/pypy", "/opt/pypy/site-packages"]:
    sys.path.insert(0, path)
    site.addsitedir(path)

if "LAMBDA_TASK_ROOT" in os.environ:
    sys.path.insert(0, os.environ["LAMBDA_TASK_ROOT"])
    site.addsitedir(os.environ["LAMBDA_TASK_ROOT"])


class LambdaContext:
    """AWS Lambda execution context object."""
    
    def __init__(self, request_id: str, invoked_function_arn: str, 
                 deadline_ms: Optional[str], trace_id: Optional[str]) -> None:
        """
        Initialize Lambda context.
        
        Args:
            request_id: The request ID for this invocation
            invoked_function_arn: The ARN of the invoked function
            deadline_ms: The deadline in milliseconds
            trace_id: The trace ID for X-Ray tracing
        """
        self.aws_request_id = request_id
        self.deadline_ms = deadline_ms
        self.function_name = os.getenv("AWS_LAMBDA_FUNCTION_NAME")
        self.function_version = os.getenv("AWS_LAMBDA_FUNCTION_VERSION")
        self.invoked_function_arn = invoked_function_arn
        self.log_group_name = os.getenv("AWS_LAMBDA_LOG_GROUP_NAME")
        self.log_stream_name = os.getenv("AWS_LAMBDA_LOG_STREAM_NAME")
        self.memory_limit_in_mb = os.getenv("AWS_LAMBDA_FUNCTION_MEMORY_SIZE")
        self.trace_id = trace_id
        
        if self.trace_id is not None:
            os.environ["_X_AMZN_TRACE_ID"] = self.trace_id

    def get_remaining_time_in_millis(self) -> Optional[float]:
        """
        Get remaining execution time in milliseconds.
        
        Returns:
            Remaining time in milliseconds or None if deadline not set
        """
        if self.deadline_ms is not None:
            return time.time() * 1000 - int(self.deadline_ms)
        return None


def decimal_serializer(obj: Any) -> Union[float, Any]:
    """
    Serialize Decimal objects to float for JSON encoding.
    
    Args:
        obj: Object to serialize
        
    Returns:
        Serialized object
        
    Raises:
        TypeError: If object is not JSON serializable
    """
    if isinstance(obj, decimal.Decimal):
        return float(obj)
    raise TypeError(f"{repr(obj)} is not JSON serializable")


def init_error(message: str, error_type: str) -> None:
    """
    Report initialization error to Lambda runtime.
    
    Args:
        message: Error message
        error_type: Type of error
    """
    details = {"errorMessage": message, "errorType": error_type}
    details_json = json.dumps(details).encode("utf-8")
    
    url = f"http://{RUNTIME_API}/{RUNTIME_API_ENDPOINT}/init/error"
    req = request.Request(url, details_json, {"Content-Type": "application/json"})
    
    try:
        with request.urlopen(req) as res:
            res.read()
    except Exception as e:
        logger.error(f"Failed to report init error: {e}")


def next_invocation() -> Tuple[str, Dict[str, Any], LambdaContext]:
    """
    Get the next invocation from Lambda runtime.
    
    Returns:
        Tuple of (request_id, event, context)
        
    Raises:
        Exception: If unable to get next invocation
    """
    url = f"http://{RUNTIME_API}/{RUNTIME_API_ENDPOINT}/invocation/next"
    
    try:
        with request.urlopen(url) as res:
            request_id = res.getheader("lambda-runtime-aws-request-id")
            invoked_function_arn = res.getheader("lambda-runtime-invoked-function-arn")
            deadline_ms = res.getheader("lambda-runtime-deadline-ms")
            trace_id = res.getheader("lambda-runtime-trace-id")
            event_payload = res.read()
            
        event = json.loads(event_payload.decode("utf-8"))
        context = LambdaContext(request_id, invoked_function_arn, deadline_ms, trace_id)
        return request_id, event, context
        
    except Exception as e:
        logger.error(f"Failed to get next invocation: {e}")
        raise


def invocation_response(request_id: str, handler_response: Union[bytes, str, Dict[str, Any]]) -> None:
    """
    Send invocation response to Lambda runtime.
    
    Args:
        request_id: The request ID
        handler_response: The response from the handler function
    """
    if not isinstance(handler_response, (bytes, str)):
        handler_response = json.dumps(handler_response, default=decimal_serializer)
    if not isinstance(handler_response, bytes):
        handler_response = handler_response.encode("utf-8")
        
    url = f"http://{RUNTIME_API}/{RUNTIME_API_ENDPOINT}/invocation/{request_id}/response"
    req = request.Request(url, handler_response, {"Content-Type": "application/json"})
    
    try:
        with request.urlopen(req) as res:
            res.read()
    except Exception as e:
        logger.error(f"Failed to send invocation response: {e}")


def invocation_error(request_id: str, error: Exception) -> None:
    """
    Send invocation error to Lambda runtime.
    
    Args:
        request_id: The request ID
        error: The exception that occurred
    """
    details = {"errorMessage": str(error), "errorType": type(error).__name__}
    details_json = json.dumps(details).encode("utf-8")
    
    url = f"http://{RUNTIME_API}/{RUNTIME_API_ENDPOINT}/invocation/{request_id}/error"
    req = request.Request(url, details_json, {"Content-Type": "application/json"})
    
    try:
        with request.urlopen(req) as res:
            res.read()
    except Exception as e:
        logger.error(f"Failed to send invocation error: {e}")


def validate_environment() -> None:
    """
    Validate required environment variables.
    
    Raises:
        RuntimeError: If required environment variables are missing
    """
    required_vars = ["AWS_LAMBDA_RUNTIME_API", "_HANDLER"]
    missing_vars = [var for var in required_vars if var not in os.environ]
    
    if missing_vars:
        error_msg = f"Missing required environment variables: {', '.join(missing_vars)}"
        logger.error(error_msg)
        init_error(error_msg, "RuntimeError")
        sys.exit(1)


def parse_handler(handler: str) -> Tuple[str, str]:
    """
    Parse handler string into module path and handler name.
    
    Args:
        handler: Handler string in format 'module.function'
        
    Returns:
        Tuple of (module_path, handler_name)
        
    Raises:
        ValueError: If handler format is invalid
    """
    try:
        module_path, handler_name = handler.rsplit(".", 1)
        if not module_path or not handler_name:
            raise ValueError("Handler must contain both module and function name")
        return module_path, handler_name
    except ValueError as e:
        error_msg = f"Invalid handler format '{handler}': {str(e)}"
        logger.error(error_msg)
        init_error(error_msg, "ValueError")
        sys.exit(1)


def import_module(module_path: str) -> Any:
    """
    Import the specified module.
    
    Args:
        module_path: Path to the module
        
    Returns:
        The imported module
        
    Raises:
        ImportError: If module cannot be imported
    """
    try:
        return __import__(module_path)
    except ImportError as e:
        error_msg = f"Failed to import module '{module_path}': {str(e)}"
        logger.error(error_msg)
        init_error(error_msg, "ImportError")
        sys.exit(1)


def get_handler_function(module: Any, handler_name: str, module_path: str) -> Any:
    """
    Get the handler function from the module.
    
    Args:
        module: The imported module
        handler_name: Name of the handler function
        module_path: Path of the module
        
    Returns:
        The handler function
        
    Raises:
        AttributeError: If handler function not found
    """
    try:
        return getattr(module, handler_name)
    except AttributeError as e:
        error_msg = f"Handler '{handler_name}' not found in module '{module_path}': {str(e)}"
        logger.error(error_msg)
        init_error(error_msg, "AttributeError")
        sys.exit(1)


def main() -> None:
    """Main function to handle Lambda runtime loop."""
    logger.info("Starting Lambda runtime")
    
    # Validate environment
    validate_environment()
    
    # Parse handler
    module_path, handler_name = parse_handler(HANDLER)
    module_path = module_path.replace("/", ".")
    
    # Import module and get handler
    module = import_module(module_path)
    handler = get_handler_function(module, handler_name, module_path)
    
    logger.info(f"Handler loaded: {module_path}.{handler_name}")
    
    # Main runtime loop
    while True:
        try:
            request_id, event, context = next_invocation()
            logger.debug(f"Processing request: {request_id}")
            
            handler_response = handler(event, context)
            invocation_response(request_id, handler_response)
            logger.debug(f"Request completed successfully: {request_id}")
            
        except Exception as e:
            logger.error(f"Handler error: {e}")
            invocation_error(request_id, e)


if __name__ == "__main__":
    main()
