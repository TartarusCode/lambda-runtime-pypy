# lambda-runtime-pypy

An AWS Lambda Runtime for [PyPy](http://pypy.org) with enhanced error handling and logging.

Derived from https://github.com/iopipe/lambda-runtime-pypy3.5

## Overview

This is an AWS Lambda Runtime for PyPy that provides a high-performance Python runtime for AWS Lambda functions. It uses [portable-pypy](https://github.com/squeaky-pl/portable-pypy), which is a statically-linked distribution of PyPy.

## Features

- **High Performance**: PyPy's JIT compiler provides significant performance improvements for CPU-intensive workloads
- **Enhanced Error Handling**: Comprehensive error reporting and logging
- **Type Safety**: Full type hints throughout the codebase
- **Robust Logging**: Structured logging with configurable levels
- **Input Validation**: Thorough validation of environment variables and handler configuration
- **Resource Management**: Proper cleanup and resource management

## Benefits of PyPy

- **Faster Execution**: JIT compilation can provide 2-10x speed improvements for certain workloads
- **Memory Efficiency**: Better memory usage patterns for long-running functions
- **Compatibility**: Full compatibility with Python standard library and most packages

## Build

To build this runtime as a layer:

```bash
make build
```

## Usage

### Basic Lambda Function

```python
def handler(event, context):
    """Example Lambda handler using PyPy runtime."""
    return {
        'statusCode': 200,
        'body': 'Hello from PyPy Lambda!'
    }
```

### Performance Optimization

```python
import json
from typing import Dict, Any

def handler(event: Dict[str, Any], context) -> Dict[str, Any]:
    """
    Optimized handler for PyPy runtime.
    
    Args:
        event: Lambda event data
        context: Lambda context object
        
    Returns:
        Response dictionary
    """
    # PyPy's JIT will optimize this loop
    result = sum(i * i for i in range(1000))
    
    return {
        'statusCode': 200,
        'body': json.dumps({'result': result})
    }
```

## Configuration

### Environment Variables

- `AWS_LAMBDA_RUNTIME_API`: Runtime API endpoint (automatically set)
- `_HANDLER`: Handler function specification (e.g., "app.handler")

### Handler Format

The handler should be specified in the format `module.function`:
- `module`: Python module path (e.g., "app" or "src.handlers.api")
- `function`: Function name within the module

## Best Practices

1. **Use Type Hints**: Leverage PyPy's type checking capabilities
2. **Optimize Loops**: PyPy's JIT excels at optimizing loops and numerical computations
3. **Warm Up**: Consider warm-up invocations for JIT compilation
4. **Memory Management**: PyPy has different memory patterns - monitor usage
5. **Error Handling**: Use structured logging for better debugging

## Performance Considerations

- **Cold Start**: PyPy may have slightly longer cold starts due to JIT compilation
- **Memory Usage**: Monitor memory usage as PyPy's GC differs from CPython
- **JIT Warm-up**: First few invocations may be slower as JIT compiles hot code paths

## Troubleshooting

### Common Issues

1. **Import Errors**: Ensure all dependencies are included in the deployment package
2. **Memory Limits**: Monitor memory usage, especially for long-running functions
3. **Timeout Issues**: PyPy may need more time for JIT compilation

### Logging

The runtime provides structured logging. Check CloudWatch logs for detailed execution information.

## License

Apache 2.0
