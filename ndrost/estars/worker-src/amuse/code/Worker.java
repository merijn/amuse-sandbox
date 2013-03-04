package amuse.code;

import java.io.IOException;
import java.io.UnsupportedEncodingException;
import java.net.InetSocketAddress;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.DoubleBuffer;
import java.nio.IntBuffer;
import java.nio.LongBuffer;
import java.nio.channels.SocketChannel;
import java.util.Arrays;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

//generated Worker class
class Worker {

    private static class AmuseMessage {
        private static final Logger logger = LoggerFactory.getLogger("ibis.amuse.AmuseMessage");

        public static final int HEADER_SIZE = 10; // integers

        // 4 byte flags field.
        public static final int HEADER_FLAGS = 0;

        // content of flags field (first 4 bytes of message header) currently:
        // - endianness
        // - if an exception has occurred
        public static final int HEADER_BIG_ENDIAN_FLAG = 0;
        public static final int HEADER_ERROR_FLAG = 1;

        public static final int HEADER_CALL_ID_INDEX = 1;
        public static final int HEADER_FUNCTION_ID_INDEX = 2;
        public static final int HEADER_CALL_COUNT_INDEX = 3;
        public static final int HEADER_INT_COUNT_INDEX = 4;
        public static final int HEADER_LONG_COUNT_INDEX = 5;
        public static final int HEADER_FLOAT_COUNT_INDEX = 6;
        public static final int HEADER_DOUBLE_COUNT_INDEX = 7;
        public static final int HEADER_BOOLEAN_COUNT_INDEX = 8;
        public static final int HEADER_STRING_COUNT_INDEX = 9;

        public static final int SIZEOF_INT = 4;
        public static final int SIZEOF_LONG = 8;
        public static final int SIZEOF_FLOAT = 4;
        public static final int SIZEOF_DOUBLE = 8;
        public static final int SIZEOF_BOOLEAN = 1;

        public static final byte TRUE_BYTE = (1 & 0xFF);
        public static final byte FALSE_BYTE = (0 & 0xFF);

        public static final int FUNCTION_ID_INIT = 10101010;
        public static final int FUNCTION_ID_STOP = 0;
        public static final int FUNCTION_ID_REDIRECT_OUTPUT = 1141573512;

        private static final long serialVersionUID = 1L;

        private static boolean hasRemaining(ByteBuffer... buffers) {
            for (ByteBuffer buffer : buffers) {
                if (buffer.hasRemaining()) {
                    return true;
                }
            }
            return false;
        }

        static void readAll(SocketChannel channel, ByteBuffer... bytes) throws IOException {

            while (hasRemaining(bytes)) {
                long read = channel.read(bytes);

                if (read == -1) {
                    throw new IOException("Connection closed on reading data");
                }
            }
        }

        private final ByteBuffer headerBytes;

        private ByteBuffer intBytes;

        private ByteBuffer longBytes;

        private ByteBuffer floatBytes;

        private ByteBuffer doubleBytes;

        private ByteBuffer booleanBytes;

        private ByteBuffer stringHeaderBytes;

        private ByteBuffer[] byteBuffers;
        private ByteBuffer[] allButStringByteBuffers;

        // UTF-8 encoded strings
        private ByteBuffer[] stringBytes;

        // view of buffers (for easy access)

        private IntBuffer header;

        private IntBuffer stringHeader;

        /**
         * Empty message.
         */
        public AmuseMessage() {
            headerBytes = ByteBuffer.allocateDirect(HEADER_SIZE * SIZEOF_INT);
            intBytes = ByteBuffer.allocateDirect(0);
            longBytes = ByteBuffer.allocateDirect(0);
            floatBytes = ByteBuffer.allocateDirect(0);
            doubleBytes = ByteBuffer.allocateDirect(0);
            booleanBytes = ByteBuffer.allocateDirect(0);
            stringHeaderBytes = ByteBuffer.allocateDirect(0);
            stringBytes = new ByteBuffer[0];

            allButStringByteBuffers = new ByteBuffer[] { headerBytes, intBytes, longBytes, floatBytes, doubleBytes,
                    booleanBytes, stringHeaderBytes };

            // no string buffers yet
            byteBuffers = allButStringByteBuffers;

            ByteOrder nativeOrder = ByteOrder.nativeOrder();

            for (ByteBuffer buffer : byteBuffers) {
                buffer.order(nativeOrder);
            }

            header = headerBytes.asIntBuffer();
            stringHeader = stringHeaderBytes.asIntBuffer();
        }

        AmuseMessage(int callID, int functionID, int count) {
            this();

            setCallID(callID);
            setFunctionID(functionID);
            setCallCount(count);
        }

        /**
         * Massages with an exception
         * 
         * @param callID
         *            id of the call that generated the exception
         * @param functionID
         *            function id tried
         * @param error
         *            a description of the error that occurred
         */
        AmuseMessage(int callID, int functionID, int count, String error) {
            this();

            setCallID(callID);
            setFunctionID(functionID);
            setCallCount(count);
            setError(error);
        }

        public void clear() {
            headerBytes.clear();

            // stuff full of zeros

            byte[] zeros = new byte[headerBytes.capacity()];

            // remember byte order
            zeros[HEADER_BIG_ENDIAN_FLAG] = headerBytes.get(HEADER_BIG_ENDIAN_FLAG);

            headerBytes.put(zeros);
        }

        /**
         * Change the byte order of this message.
         * 
         * @param order
         *            The new byte-order
         */
        private void setByteOrder(ByteOrder order) {
            if (order == ByteOrder.BIG_ENDIAN) {
                headerBytes.put(HEADER_BIG_ENDIAN_FLAG, TRUE_BYTE);
            } else {
                headerBytes.put(HEADER_BIG_ENDIAN_FLAG, FALSE_BYTE);
            }

            for (ByteBuffer buffer : getByteBuffers(false)) {
                buffer.order(order);
            }

            // re-create views, as the order-change may not become visible
            // otherwise
            headerBytes.clear();
            header = headerBytes.asIntBuffer();
            stringHeaderBytes.clear();
            stringHeader = stringHeaderBytes.asIntBuffer();
        }

        /**
         * Change the byte order of this message. Also swaps the content of all
         * the buffers, if requested.
         * 
         * @param order
         *            The new byte-order
         * @param swapContent
         *            if True, all data contained in this message is byte-order
         *            swapped.
         * @throws IOException
         *             if the byte order cannot be determined
         */
        void setByteOrder(ByteOrder order, boolean swapContent) throws IOException {
            ByteOrder oldOrder = getByteOrder();

            if (order == oldOrder) {
                // done! :-)
                return;
            }

            throw new IOException("byte swapping not implemented yet!");
        }

        private ByteOrder getByteOrder() {
            if (headerBytes.get(HEADER_BIG_ENDIAN_FLAG) == TRUE_BYTE) {
                return ByteOrder.BIG_ENDIAN;
            } else if (headerBytes.get(HEADER_BIG_ENDIAN_FLAG) == FALSE_BYTE) {
                return ByteOrder.LITTLE_ENDIAN;
            } else {
                throw new RuntimeException("endiannes not specified in header");
            }
        }

        public void setCallCount(int count) {
            header.put(HEADER_CALL_COUNT_INDEX, count);
        }

        public void setFunctionID(int functionID) {
            header.put(HEADER_FUNCTION_ID_INDEX, functionID);
        }

        public void setCallID(int callID) {
            header.put(HEADER_CALL_ID_INDEX, callID);
        }

        public void setError(String error) {
            if (error == null) {
                error = "<empty>";
            }
            // clear data from message
            header.put(HEADER_INT_COUNT_INDEX, 0);
            header.put(HEADER_LONG_COUNT_INDEX, 0);
            header.put(HEADER_FLOAT_COUNT_INDEX, 0);
            header.put(HEADER_DOUBLE_COUNT_INDEX, 0);
            header.put(HEADER_BOOLEAN_COUNT_INDEX, 0);
            header.put(HEADER_STRING_COUNT_INDEX, 1);

            // set error state
            headerBytes.put(HEADER_ERROR_FLAG, TRUE_BYTE);

            ensurePrimitiveCapacity();

            try {
                // set first string to exception message
                byte[] bytes;

                bytes = error.getBytes("UTF-8");

                stringHeader.put(0, bytes.length);

                ensureStringsCapacity();

                stringBytes[0].clear();
                stringBytes[0].put(bytes);
            } catch (UnsupportedEncodingException e) {
                logger.error("could not set error", e);
                stringHeader.put(0, 0);
            }
        }

        public void addString(String value) {
            int position = header.get(HEADER_STRING_COUNT_INDEX);

            // add an extra string
            header.put(HEADER_STRING_COUNT_INDEX, position + 1);

            // make sure there is space in the header for the length of the
            // string
            ensurePrimitiveCapacity();

            // encode string to UTF-8
            byte[] bytes;

            try {
                bytes = value.getBytes("UTF-8");

                // set length of string in header
                stringHeader.put(position, bytes.length);

                // make sure there is space for the string
                ensureStringsCapacity();

                stringBytes[position].clear();
                stringBytes[position].put(bytes);

            } catch (UnsupportedEncodingException e) {
                logger.error("ERROR! UTF-8 not supported by the JVM!");
            }
        }

        // public void addInteger(int value) {
        // header.put(HEADER_INT_COUNT_INDEX, header.get(HEADER_INT_COUNT_INDEX)
        // + 1);
        // ensurePrimitiveCapacity();
        // intBytes.clear();
        // intBytes.asIntBuffer().put(header.get(HEADER_INT_COUNT_INDEX),
        // value);
        // }

        public boolean isErrorState() {
            return headerBytes.get(HEADER_ERROR_FLAG) == TRUE_BYTE;
        }

        public String getError() throws IOException {
            if (!isErrorState()) {
                return null;
            }
            return getString(0);
        }

        public int getCallID() {
            return header.get(HEADER_CALL_ID_INDEX);
        }

        public int getFunctionID() {
            return header.get(HEADER_FUNCTION_ID_INDEX);
        }

        public int getCallCount() {
            return header.get(HEADER_CALL_COUNT_INDEX);
        }

        public int getIntCount() {
            return header.get(HEADER_INT_COUNT_INDEX);
        }

        public int getLongCount() {
            return header.get(HEADER_LONG_COUNT_INDEX);
        }

        public int getFloatCount() {
            return header.get(HEADER_FLOAT_COUNT_INDEX);
        }

        public int getDoubleCount() {
            return header.get(HEADER_DOUBLE_COUNT_INDEX);
        }

        public int getBooleanCount() {
            return header.get(HEADER_BOOLEAN_COUNT_INDEX);
        }

        public int getStringCount() {
            return header.get(HEADER_STRING_COUNT_INDEX);
        }

        public String getString(int index) throws IOException {
            if (getStringCount() <= index) {
                throw new IOException("cannot get string at index " + index + " in call" + this);
            }

            if (stringBytes.length <= index) {
                throw new IOException("cannot get string at index " + index + " in call" + this
                        + " header does not match content!");

            }

            int utf8length = stringHeader.get(index);

            if (stringBytes[index].hasArray()) {
                return new String(stringBytes[index].array(), 0, utf8length, "UTF-8");
            }
            byte[] bytes = new byte[utf8length];
            stringBytes[index].position(0);
            stringBytes[index].limit(utf8length);
            stringBytes[index].get(bytes);

            return new String(bytes, 0, utf8length, "UTF-8");
        }

        public boolean getBoolean(int index) {
            byte rawByte = booleanBytes.get(index);

            return rawByte == TRUE_BYTE;

        }

        public int getInteger(int index) {
            return intBytes.getInt(index * SIZEOF_INT);
        }

        /**
         * Get all buffers, possibly including the buffers containing the
         * strings.
         * 
         * @return all buffers.
         * 
         * @param includeStringBuffers
         *            if true, the buffers for holding the values of strings
         *            will be included.
         */
        public ByteBuffer[] getByteBuffers(boolean includeStringBuffers) {
            if (includeStringBuffers) {
                return byteBuffers;
            } else {
                return allButStringByteBuffers;
            }
        }

        public ByteBuffer[] getStringByteBuffers() {
            return stringBytes;
        }

        private void setPrimitiveLimitsFromHeader() throws IOException {
            intBytes.clear().limit(getIntCount() * SIZEOF_INT);
            longBytes.clear().limit(getLongCount() * SIZEOF_LONG);
            floatBytes.clear().limit(getFloatCount() * SIZEOF_FLOAT);
            doubleBytes.clear().limit(getDoubleCount() * SIZEOF_DOUBLE);
            booleanBytes.clear().limit(getBooleanCount() * SIZEOF_BOOLEAN);
            stringHeaderBytes.clear().limit(getStringCount() * SIZEOF_INT);
        }

        private void setStringLimitsFromHeader() throws IOException {
            if (getStringCount() > stringBytes.length) {
                throw new IOException(
                        "Amuse message in inconsistent state, strign count greater than number of string buffers");
            }

            for (int i = 0; i < getStringCount(); i++) {
                int utf8Length = stringHeader.get(i);

                stringBytes[i].clear().limit(utf8Length);
            }

            // set the limit of the rest of the string bytes to 0
            for (int i = getStringCount(); i < stringBytes.length; i++) {
                stringBytes[i].limit(0);
            }
        }

        void writeTo(SocketChannel channel) throws IOException {
            if (logger.isTraceEnabled()) {
                logger.trace("writing to socket channel: " + this.toContentString());
            } else if (logger.isDebugEnabled()) {
                logger.debug("writing to socket channel: " + this);
            }

            headerBytes.clear();
            setPrimitiveLimitsFromHeader();
            setStringLimitsFromHeader();

            // write to channel
            channel.write(byteBuffers);

            // alternative, debugging version of writing buffers
            // for (ByteBuffer buffer : byteBuffers) {
            // logger.debug("writing " + buffer + " of length "
            // + buffer.remaining());
            // channel.write(buffer);
            //
            // if (buffer.hasRemaining()) {
            // logger.error("Error! not all bytes written "
            // + buffer.remaining());
            // }
            // }
        }

        // make sure there is enough space for each primitive buffer
        // (including the string header)
        public boolean ensurePrimitiveCapacity() {
            boolean buffersUpdated = false;

            if (getIntCount() * SIZEOF_INT > intBytes.capacity()) {
                intBytes = ByteBuffer.allocateDirect(getIntCount() * SIZEOF_INT);
                intBytes.order(getByteOrder());
                buffersUpdated = true;
            }

            if (getLongCount() * SIZEOF_LONG > longBytes.capacity()) {
                longBytes = ByteBuffer.allocateDirect(getLongCount() * SIZEOF_LONG);
                longBytes.order(getByteOrder());
                buffersUpdated = true;
            }

            if (getFloatCount() * SIZEOF_FLOAT > floatBytes.capacity()) {
                floatBytes = ByteBuffer.allocateDirect(getFloatCount() * SIZEOF_FLOAT);
                floatBytes.order(getByteOrder());
                buffersUpdated = true;
            }

            if (getDoubleCount() * SIZEOF_DOUBLE > doubleBytes.capacity()) {
                doubleBytes = ByteBuffer.allocateDirect(getDoubleCount() * SIZEOF_DOUBLE);
                doubleBytes.order(getByteOrder());
                buffersUpdated = true;
            }

            if (getBooleanCount() * SIZEOF_BOOLEAN > booleanBytes.capacity()) {
                booleanBytes = ByteBuffer.allocateDirect(getBooleanCount() * SIZEOF_BOOLEAN);
                booleanBytes.order(getByteOrder());
                buffersUpdated = true;
            }

            if (getStringCount() * SIZEOF_INT > stringHeaderBytes.capacity()) {
                stringHeaderBytes = ByteBuffer.allocateDirect(getStringCount() * SIZEOF_INT);
                stringHeaderBytes.order(getByteOrder());
                stringHeader = stringHeaderBytes.asIntBuffer();
                buffersUpdated = true;
            }

            if (buffersUpdated) {
                allButStringByteBuffers = new ByteBuffer[] { headerBytes, intBytes, longBytes, floatBytes, doubleBytes,
                        booleanBytes, stringHeaderBytes };

                // update byte buffers array
                ByteBuffer[] newByteBuffers = new ByteBuffer[allButStringByteBuffers.length + stringBytes.length];
                for (int i = 0; i < allButStringByteBuffers.length; i++) {
                    newByteBuffers[i] = allButStringByteBuffers[i];
                }
                for (int i = 0; i < stringBytes.length; i++) {
                    newByteBuffers[allButStringByteBuffers.length + i] = stringBytes[i];
                }
                byteBuffers = newByteBuffers;

                if (logger.isTraceEnabled()) {
                    logger.trace("ensurePrimitiveCapacity() Updated buffers to " + Arrays.toString(byteBuffers));
                }
            }

            return buffersUpdated;
        }

        public boolean ensureStringsCapacity() {
            // checking if the string header is big enough is checked above, so
            // we
            // only check if all strings listed in the header
            boolean buffersUpdated = false;

            if (stringBytes.length < getStringCount()) {
                ByteBuffer[] oldStringBytes = stringBytes;
                stringBytes = new ByteBuffer[getStringCount()];
                for (int i = 0; i < oldStringBytes.length; i++) {
                    stringBytes[i] = oldStringBytes[i];
                }
                buffersUpdated = true;
            }

            for (int i = 0; i < getStringCount(); i++) {
                int stringLength = stringHeader.get(i);
                if (stringBytes[i] == null || stringLength > stringBytes[i].capacity()) {

                    stringBytes[i] = ByteBuffer.allocateDirect(stringLength);
                    buffersUpdated = true;
                }
            }

            if (buffersUpdated) {
                // update byte buffers array
                ByteBuffer[] newByteBuffers = new ByteBuffer[allButStringByteBuffers.length + stringBytes.length];
                for (int i = 0; i < allButStringByteBuffers.length; i++) {
                    newByteBuffers[i] = allButStringByteBuffers[i];
                }
                for (int i = 0; i < stringBytes.length; i++) {
                    newByteBuffers[allButStringByteBuffers.length + i] = stringBytes[i];
                }
                byteBuffers = newByteBuffers;

                if (logger.isTraceEnabled()) {
                    logger.trace("ensureStringsCapacity() Updated buffers to " + Arrays.toString(byteBuffers));
                }
            }

            return buffersUpdated;
        }

        boolean readFrom(SocketChannel channel) throws IOException {
            boolean updatedBuffers = false;

            logger.trace("receiving header from channel");

            headerBytes.clear();

            readAll(channel, headerBytes);

            // set buffers to byte order specified in buffer
            setByteOrder(getByteOrder());

            logger.trace("reading content for " + this);

            if (ensurePrimitiveCapacity()) {
                updatedBuffers = true;
            }

            // then, set limits for primitive buffers, and receive those

            setPrimitiveLimitsFromHeader();

            logger.trace("receiving primitives from channel");

            headerBytes.position(headerBytes.limit());
            // we also request to read the header, but its position is already
            // equal to its limit, so no bytes are read into it.
            readAll(channel, allButStringByteBuffers);

            // make sure there is enough space for the strings
            if (ensureStringsCapacity()) {
                updatedBuffers = true;
            }

            // set the limits
            setStringLimitsFromHeader();

            logger.trace("receiving strings from channel");

            // and receive!
            readAll(channel, stringBytes);

            if (logger.isDebugEnabled()) {
                logger.debug("done receiving message from channel: " + this);
            }

            return updatedBuffers;
        }

        public String toContentString() throws IOException {
            String message = "AmuseMessage <id:" + getCallID() + " function ID:" + getFunctionID() + " count:"
                    + getCallCount();

            if (isErrorState()) {
                message = message + " ERROR";
            }

            if (getByteOrder() == ByteOrder.BIG_ENDIAN) {
                message = message + " order: B";
            } else {
                message = message + " order: l";
            }

            if (getIntCount() != 0) {
                message = message + " ints: [";
                for (int i = 0; i < getIntCount(); i++) {
                    message = message + ", " + intBytes.getInt(i * SIZEOF_INT);
                }
                message = message + "] ";
            }

            if (getLongCount() != 0) {
                message = message + " longs: [";
                for (int i = 0; i < getLongCount(); i++) {
                    message = message + ", " + longBytes.getLong(i * SIZEOF_LONG);
                }
                message = message + "] ";
            }

            if (getFloatCount() != 0) {
                message = message + " floats: [";
                for (int i = 0; i < getFloatCount(); i++) {
                    message = message + ", " + floatBytes.getFloat(i * SIZEOF_FLOAT);
                }
                message = message + "] ";
            }

            if (getDoubleCount() != 0) {
                message = message + " double: [";
                for (int i = 0; i < getDoubleCount(); i++) {
                    message = message + ", " + doubleBytes.getDouble(i * SIZEOF_DOUBLE);
                }
                message = message + "] ";
            }

            if (getBooleanCount() != 0) {
                message = message + " boolean: [";
                for (int i = 0; i < getBooleanCount(); i++) {
                    message = message + ", " + getBoolean(i);
                }
                message = message + "] ";
            }

            if (getStringCount() != 0) {
                message = message + " string: [";
                for (int i = 0; i < getStringCount(); i++) {
                    message = message + ", " + getString(i);
                }
                message = message + "] ";
            }

            message = message + ">";

            // return "Call <id:" + getCallID() + " function ID:" +
            // getFunctionID()
            // + " count:" + getCount() + " ints:" + getIntCount()
            // + " longs: " + getLongCount() + " floats:" + getFloatCount()
            // + " doubles:" + getDoubleCount() + " booleans:"
            // + getBooleanCount() + " strings:" + getStringCount()
            // + " byte order:" + getByteOrder() + " error:"
            // + isErrorState() + ">";

            return message;
        }

        public String toString() {
            String message = "AmuseMessage <id:" + getCallID() + " function ID:" + getFunctionID() + " count:"
                    + getCallCount();

            if (isErrorState()) {
                message = message + " ERROR";
            }

            if (getByteOrder() == ByteOrder.BIG_ENDIAN) {
                message = message + " order: B";
            } else {
                message = message + " order: l";
            }

            if (getIntCount() != 0) {
                message = message + " ints:" + getIntCount();
            }

            if (getLongCount() != 0) {
                message = message + " longs:" + getLongCount();
            }

            if (getFloatCount() != 0) {
                message = message + " floats:" + getFloatCount();
            }

            if (getDoubleCount() != 0) {
                message = message + " doubles:" + getDoubleCount();
            }

            if (getBooleanCount() != 0) {
                message = message + " booleans:" + getBooleanCount();
            }

            if (getStringCount() != 0) {
                message = message + " strings:" + getStringCount();
            }

            message = message + ">";

            // return "Call <id:" + getCallID() + " function ID:" +
            // getFunctionID()
            // + " count:" + getCount() + " ints:" + getIntCount()
            // + " longs: " + getLongCount() + " floats:" + getFloatCount()
            // + " doubles:" + getDoubleCount() + " booleans:"
            // + getBooleanCount() + " strings:" + getStringCount()
            // + " byte order:" + getByteOrder() + " error:"
            // + isErrorState() + ">";

            return message;
        }

        public void setDataCount(int ints, int longs, int floats, int doubles, int booleans, int strings) {
            header.put(HEADER_INT_COUNT_INDEX, ints);
            header.put(HEADER_LONG_COUNT_INDEX, longs);
            header.put(HEADER_FLOAT_COUNT_INDEX, floats);
            header.put(HEADER_DOUBLE_COUNT_INDEX, doubles);
            header.put(HEADER_BOOLEAN_COUNT_INDEX, booleans);
            header.put(HEADER_STRING_COUNT_INDEX, strings);

            ensurePrimitiveCapacity();
        }

        public int[] getIntSlice(int sliceIndex) {
            int[] result = new int[getCallCount()];

            intBytes.position(getCallCount() * sliceIndex * SIZEOF_INT);
            intBytes.limit(getCallCount() * (sliceIndex + 1) * SIZEOF_INT);

            intBytes.asIntBuffer().get(result);

            return result;
        }

        public double[] getDoubleSlice(int sliceIndex) {
            double[] result = new double[getCallCount()];

            doubleBytes.position(getCallCount() * sliceIndex * SIZEOF_DOUBLE);
            doubleBytes.limit(getCallCount() * (sliceIndex + 1) * SIZEOF_DOUBLE);

            doubleBytes.asDoubleBuffer().get(result);

            return result;
        }

        // sets all elements of a slice
        public void setIntSlice(int sliceIndex, int[] data) {
            intBytes.position(getCallCount() * sliceIndex * SIZEOF_INT);
            intBytes.limit(getCallCount() * (sliceIndex + 1) * SIZEOF_INT);

            intBytes.asIntBuffer().put(data);
        }

        // sets a single element of a slice
        public void setIntElement(int sliceIndex, int index, int value) {
            intBytes.position(getCallCount() * sliceIndex * SIZEOF_INT);
            intBytes.limit(getCallCount() * (sliceIndex + 1) * SIZEOF_INT);

            intBytes.asIntBuffer().put(index, value);
        }
    }

    private final AmuseMessage request;
    private final AmuseMessage reply;

    private final CodeInterface code;

    Worker() {
        this.request = new AmuseMessage();
        this.reply = new AmuseMessage();

        // generated
        code = new nl.esciencecenter.estars.Code();
    }

    // generated
    private boolean handleCall() throws IOException {
        int count = request.getCallCount();

        switch (request.getFunctionID()) {

        case 0:
            // end.
            return false;

        case 223890289:
            reply.setDataCount(1 * count, 0, 0, 0, 0, 0);

            reply.setIntElement(0, 0, code.set_color(request.getIntSlice(0), request.getDoubleSlice(0),
                    request.getDoubleSlice(1), request.getDoubleSlice(2), request.getDoubleSlice(3), count));
            break;

        case 290264013:
            reply.setDataCount(2 * count, 0, 0, 0, 0, 0);

            int[] output = new int[count];
            
            reply.setIntElement(0,0,
                    code.new_particle(output, request.getIntSlice(0), request.getDoubleSlice(0),
                            request.getDoubleSlice(1), request.getDoubleSlice(2), request.getDoubleSlice(3),
                            request.getDoubleSlice(4), request.getDoubleSlice(5), request.getDoubleSlice(6),
                            request.getDoubleSlice(7), count));
            reply.setIntSlice(1,  output);
            break;
        case 421115296:
            reply.setDataCount(1 * count, 0, 0, 0, 0, 0);
            reply.setIntElement(0,0,code.set_type(request.getIntSlice(0), request.getIntSlice(1), count));
            break;

        case 474219840:
            reply.setDataCount(1 * count, 0, 0, 0, 0, 0);
            reply.setIntElement(0,0,code.store_view(request.getDoubleSlice(0)[0]));
            break;
        case 1644113439:
            reply.setDataCount(1 * count, 0, 0, 0, 0, 0);
            reply.setIntElement(0,0,code.cleanup_code());
            break;
        case 1744145122:
            reply.setDataCount(1 * count, 0, 0, 0, 0, 0);
            reply.setIntElement(0,0,code.recommit_parameters());
            break;
        case 1768994498:
            reply.setDataCount(1 * count, 0, 0, 0, 0, 0);
            reply.setIntElement(0,0,code.initialize_code());
            break;
        case 2026192840:
            reply.setDataCount(1 * count, 0, 0, 0, 0, 0);
            reply.setIntElement(0,0,
                    code.set_position(request.getIntSlice(0), request.getDoubleSlice(0),
                            request.getDoubleSlice( 1), request.getDoubleSlice( 2), count));
            break;
        case 2069478464:
            reply.setDataCount(1 * count, 0, 0, 0, 0, 0);
            reply.setIntElement(0,0,code.commit_parameters());
            break;
        case 20920053:
            reply.setDataCount(1 * count, 0, 0, 0, 0, 0);
            reply.setIntElement(0,0,code.commit_parameters());
            break;

        default:
            throw new IOException("unknown function id " + request.getFunctionID());

        }
        return true;
    }

    private void runSockets(int port) {
        try (SocketChannel channel = SocketChannel.open(new InetSocketAddress(port));) {
            boolean keepRunning = true;
            while (keepRunning) {
                request.clear();
                request.readFrom(channel);

                System.err.println("got message " + request.toContentString());

                reply.clear();

                reply.setCallID(request.getCallID());
                reply.setFunctionID(request.getFunctionID());
                reply.setCallCount(request.getCallCount());

                keepRunning = handleCall();

                System.err.println("sending reply message " + reply.toContentString());

                reply.writeTo(channel);
            }
        } catch (IOException e) {
            System.err.println("Error running worker: " + e.getMessage());
        }
    }

    public static void main(String[] arguments) throws IOException {

        System.err.println("Java eStars Worker");
        for (String argument : arguments) {
            System.err.println("argument: " + argument);
        }

        if (arguments.length == 0) {
            System.err.println("No arguments to worker. expected a socket port number");
            System.exit(1);
        }

        int port = Integer.parseInt(arguments[0]);

        new Worker().runSockets(port);

    }
}