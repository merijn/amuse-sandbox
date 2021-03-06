#include <stdint.h>

#ifndef AMUSE_RPC_H
#define AMUSE_RPC_H

//interface for rpc calls to community codes. Calls may come from
//a socket worker, java, etc.

//first 4 bytes reserved for flags
const int AMUSE_RPC_HEADER_SIZE = 10; // integers

const int AMUSE_RPC_HEADER_FLAGS = 0;
const int AMUSE_RPC_HEADER_CALL_ID = 1;
const int AMUSE_RPC_HEADER_FUNCTION_ID = 2;
const int AMUSE_RPC_HEADER_CALL_COUNT = 3;
const int AMUSE_RPC_HEADER_INT_COUNT = 4;
const int AMUSE_RPC_HEADER_LONG_COUNT = 5;
const int AMUSE_RPC_HEADER_FLOAT_COUNT = 6;
const int AMUSE_RPC_HEADER_DOUBLE_COUNT = 7;
const int AMUSE_RPC_HEADER_BOOLEAN_COUNT = 8;
const int AMUSE_RPC_HEADER_STRING_COUNT = 9;

const int AMUSE_RPC_SIZEOF_INT = 4;
const int AMUSE_RPC_SIZEOF_LONG = 8;
const int AMUSE_RPC_SIZEOF_FLOAT = 4;
const int AMUSE_RPC_SIZEOF_DOUBLE = 8;
const int AMUSE_RPC_SIZEOF_BOOLEAN = 1;

//characters. To make things slightly simpler, strings have a fixed maximum
//size (size in characters).
const int AMUSE_RPC_MAX_STRING_SIZE = 255;

//first four bytes of the header contain flags (as one byte booleans)

//endiannes of message
const int AMUSE_RPC_HEADER_FLAG_ENDIANESS = 0;

//error flag. true if an error has occurred.
//By convention, the error message will be in the first string buffer.
const int AMUSE_RPC_HEADER_FLAG_ERROR = 1;

//booleans
const int AMUSE_RPC_BOOLEAN_TRUE = 1;
const int AMUSE_RPC_BOOLEAN_FALSE = 0;

// -----        FUNCTIONS AVAILABLE FOR CODES        -----

//set error flag in output buffers, set error message to given string
void amuse_rpc_set_error(char *string);

//ensure buffers are big enough to hold all data. sizes need to be specified in the header
//if buffers are not big enough, a call to rpc_set_output_buffers will be made with the updated buffers
void amuse_rpc_ensure_capacity();

// ----- FUNCTIONS WHICH MUST BE IMPLEMENTED BY CODES -----

//sets buffers to be used for input.

void amuse_rpc_set_input_buffers(int *header, int *integers, int *longs);

//sets buffers to be used for output
void amuse_rpc_set_output_buffers(int32_t *header, int32_t *integers);

//actual call to code. expects the code to take the input from the input
//buffers, and return the output (or any error) in the output buffers
void amuse_rpc_call();

#endif /* AMUSE_RPC_H */
