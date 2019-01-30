/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 LICENSE:
 IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 
 Abstract:
 An object wrapper around the low-level BSD Sockets ping function.
 
 Modified by dustturtle:openglnewbee@163.com, follow the license below.
 */

#import "PingFoundation.h"

#include <sys/socket.h>
#include <netinet/in.h>
#include <errno.h>

#pragma mark * IPv4 and ICMPv4 On-The-Wire Format

/*! Describes the on-the-wire header format for an IPv4 packet.
 *  \details This defines the header structure of IPv4 packets on the wire.  We need
 *      this in order to skip this header in the IPv4 case, where the kernel passes
 *      it to us for no obvious reason.
 */

struct IPv4Header {
    uint8_t     versionAndHeaderLength;
    uint8_t     differentiatedServices;
    uint16_t    totalLength;
    uint16_t    identification;
    uint16_t    flagsAndFragmentOffset;
    uint8_t     timeToLive;
    uint8_t     protocol;
    uint16_t    headerChecksum;
    uint8_t     sourceAddress[4];
    uint8_t     destinationAddress[4];
    // options...
    // data...
};
typedef struct IPv4Header IPv4Header;

__Check_Compile_Time(sizeof(IPv4Header) == 20);
__Check_Compile_Time(offsetof(IPv4Header, versionAndHeaderLength) == 0);
__Check_Compile_Time(offsetof(IPv4Header, differentiatedServices) == 1);
__Check_Compile_Time(offsetof(IPv4Header, totalLength) == 2);
__Check_Compile_Time(offsetof(IPv4Header, identification) == 4);
__Check_Compile_Time(offsetof(IPv4Header, flagsAndFragmentOffset) == 6);
__Check_Compile_Time(offsetof(IPv4Header, timeToLive) == 8);
__Check_Compile_Time(offsetof(IPv4Header, protocol) == 9);
__Check_Compile_Time(offsetof(IPv4Header, headerChecksum) == 10);
__Check_Compile_Time(offsetof(IPv4Header, sourceAddress) == 12);
__Check_Compile_Time(offsetof(IPv4Header, destinationAddress) == 16);

/*! Calculates an IP checksum.
 *  \details This is the standard BSD checksum code, modified to use modern types.
 *  \param buffer A pointer to the data to checksum.
 *  \param bufferLen The length of that data.
 *  \returns The checksum value, in network byte order.
 */

static uint16_t in_cksum(const void *buffer, size_t bufferLen) {
    //
    size_t              bytesLeft;
    int32_t             sum;
    const uint16_t *    cursor;
    union {
        uint16_t        us;
        uint8_t         uc[2];
    } last;
    uint16_t            answer;
    
    bytesLeft = bufferLen;
    sum = 0;
    cursor = buffer;
    
    /*
     * Our algorithm is simple, using a 32 bit accumulator (sum), we add
     * sequential 16 bit words to it, and at the end, fold back all the
     * carry bits from the top 16 bits into the lower 16 bits.
     */
    while (bytesLeft > 1) {
        sum += *cursor;
        cursor += 1;
        bytesLeft -= 2;
    }
    
    /* mop up an odd byte, if necessary */
    if (bytesLeft == 1) {
        last.uc[0] = * (const uint8_t *) cursor;
        last.uc[1] = 0;
        sum += last.us;
    }
    
    /* add back carry outs from top 16 bits to low 16 bits */
    sum = (sum >> 16) + (sum & 0xffff);	/* add hi 16 to low 16 */
    sum += (sum >> 16);			/* add carry */
    answer = (uint16_t) ~sum;   /* truncate to 16 bits */
    
    return answer;
}

#pragma mark * PingFoundation

const uint16_t HttpModeSequenceNumber = 0x8888;

@interface PingFoundation ()

// read/write versions of public properties

@property (nonatomic, copy,   readwrite, nullable) NSData *     hostAddress;
@property (nonatomic, assign, readwrite          ) uint16_t     nextSequenceNumber;

// private properties

/*! True if nextSequenceNumber has wrapped from 65535 to 0.
 */

@property (nonatomic, assign, readwrite)           BOOL         nextSequenceNumberHasWrapped;

/*! A host object for name-to-address resolution.
 */

@property (nonatomic, strong, readwrite, nullable) CFHostRef host __attribute__ ((NSObject));

/*! A socket object for ICMP send and receive.
 */

@property (nonatomic, strong, readwrite, nullable) CFSocketRef socket __attribute__ ((NSObject));

@end

@implementation PingFoundation

- (instancetype)initWithHostName:(NSString *)hostName withHttpMode:(BOOL)httpMode
{
    if ([hostName length] <= 0)
    {
        return nil;
    }

    self = [super init];
    if (self != nil) {
        self->_hostName   = [hostName copy];
        self->_httpMode = httpMode;
        self->_identifier = (uint16_t) arc4random();
    }
    return self;
}

- (void)dealloc
{
    [self stop];
}

- (sa_family_t)hostAddressFamily {
    sa_family_t     result;
    
    result = AF_UNSPEC;
    if ( (self.hostAddress != nil) && (self.hostAddress.length >= sizeof(struct sockaddr)) )
    {
        result = ((const struct sockaddr *) self.hostAddress.bytes)->sa_family;
    }
    return result;
}

/*! Shuts down the pinger object and tell the delegate about the error.
 *  \param error Describes the failure.
 */

- (void)didFailWithError:(NSError *)error {
    id<PingFoundationDelegate>  strongDelegate;
    
    // We retain ourselves temporarily because it's common for the delegate method
    // to release its last reference to us, which causes -dealloc to be called here.
    // If we then reference self on the return path, things go badly.  I don't think
    // that happens currently, but I've got into the habit of doing this as a
    // defensive measure.
    
    CFAutorelease(CFBridgingRetain(self));
    
    [self stop];
    
    strongDelegate = self.delegate;
    if ((strongDelegate != nil) && [strongDelegate respondsToSelector:@selector(pingFoundation:didFailWithError:)])
    {
        [strongDelegate pingFoundation:self didFailWithError:error];
    }
}

/*! Shuts down the pinger object and tell the delegate about the error.
 *  \details This converts the CFStreamError to an NSError and then call through to
 *      -didFailWithError: to do the real work.
 *  \param streamError Describes the failure.
 */

- (void)didFailWithHostStreamError:(CFStreamError)streamError {
    NSDictionary *  userInfo;
    NSError *       error;
    
    if (streamError.domain == kCFStreamErrorDomainNetDB) {
        userInfo = @{(id) kCFGetAddrInfoFailureKey: @(streamError.error)};
    } else {
        userInfo = nil;
    }
    error = [NSError errorWithDomain:(NSString *) kCFErrorDomainCFNetwork code:kCFHostErrorUnknown userInfo:userInfo];
    
    [self didFailWithError:error];
}

/*! Builds a ping packet from the supplied parameters.
 *  \param type The packet type, which is different for IPv4 and IPv6.
 *  \param payload Data to place after the ICMP header.
 *  \param requiresChecksum Determines whether a checksum is calculated (IPv4) or not (IPv6).
 *  \returns A ping packet suitable to be passed to the kernel.
 */

- (NSData *)pingPacketWithType:(uint8_t)type payload:(NSData *)payload requiresChecksum:(BOOL)requiresChecksum {
    NSMutableData *         packet;
    ICMPHeader *            icmpPtr;
    
    packet = [NSMutableData dataWithLength:sizeof(*icmpPtr) + payload.length];
    
    icmpPtr = packet.mutableBytes;
    icmpPtr->type = type;
    icmpPtr->code = 0;
    icmpPtr->checksum = 0;
    icmpPtr->identifier     = OSSwapHostToBigInt16(self.identifier);
    icmpPtr->sequenceNumber = OSSwapHostToBigInt16(self.nextSequenceNumber);
    memcpy(&icmpPtr[1], [payload bytes], [payload length]);
    
    if (requiresChecksum) {
        // The IP checksum routine returns a 16-bit number that's already in correct byte order
        // (due to wacky 1's complement maths), so we just put it into the packet as a 16-bit unit.
        
        icmpPtr->checksum = in_cksum(packet.bytes, packet.length);
    }
    
    return packet;
}

- (void)sendPingWithData:(NSData *)data {
    int                     err;
    NSData *                payload;
    NSData *                packet;
    ssize_t                 bytesSent;
    id<PingFoundationDelegate>  strongDelegate;
    
    // data may be nil
    
    // Construct the ping packet.
    
    payload = data;
    if (payload == nil)
    {
        payload = [[NSString stringWithFormat:@"%28zd bottles of beer on the wall", (ssize_t) 99 - (size_t) (self.nextSequenceNumber % 100) ] dataUsingEncoding:NSASCIIStringEncoding];
        // Our dummy payload is sized so that the resulting ICMP packet, including the ICMPHeader, is
        // 64-bytes, which makes it easier to recognise our packets on the wire.
    }
    
    switch (self.hostAddressFamily) {
        case AF_INET: {
            packet = [self pingPacketWithType:ICMPv4TypeEchoRequest payload:payload requiresChecksum:YES];
        } break;
        case AF_INET6: {
            packet = [self pingPacketWithType:ICMPv6TypeEchoRequest payload:payload requiresChecksum:NO];
        } break;
        default: {
            assert(NO);
        } break;
    }
    
    // Send the packet.
    
    if (self.socket == NULL) {
        bytesSent = -1;
        err = EBADF;
    } else {
        bytesSent = sendto(
                           CFSocketGetNative(self.socket),
                           packet.bytes,
                           packet.length,
                           0,
                           self.hostAddress.bytes,
                           (socklen_t) self.hostAddress.length
                           );
        err = 0;
        if (bytesSent < 0) {
            err = errno;
        }
    }
    
    // Handle the results of the send.
    
    strongDelegate = self.delegate;
    if ( (bytesSent > 0) && (((NSUInteger) bytesSent) == packet.length) ) {
        
        // Complete success.  Tell the client.
        
        if ( (strongDelegate != nil) && [strongDelegate respondsToSelector:@selector(pingFoundation:didSendPacket:sequenceNumber:)] ) {
            [strongDelegate pingFoundation:self didSendPacket:packet sequenceNumber:self.nextSequenceNumber];
        }
    } else {
        NSError *   error;
        
        // Some sort of failure.  Tell the client.
        
        if (err == 0) {
            err = ENOBUFS;          // This is not a hugely descriptor error, alas.
        }
        error = [NSError errorWithDomain:NSPOSIXErrorDomain code:err userInfo:nil];
        if ( (strongDelegate != nil) && [strongDelegate respondsToSelector:@selector(pingFoundation:didFailToSendPacket:sequenceNumber:error:)] ) {
            [strongDelegate pingFoundation:self didFailToSendPacket:packet sequenceNumber:self.nextSequenceNumber error:error];
        }
    }
    
    self.nextSequenceNumber += 1;
    if (self.nextSequenceNumber == 0) {
        self.nextSequenceNumberHasWrapped = YES;
    }
}

-(void)sendHttpPingWithData:(NSString *)method path:(NSString *)path {
    int                     err;
    NSData *                packet;
    ssize_t                 bytesSent;
    id<PingFoundationDelegate>  strongDelegate;
    
    // data may be nil
    
    // Construct the ping packet.
    
    NSMutableString* requestString  =   [[NSMutableString alloc] init];
    [requestString appendFormat:@"%@ %@ HTTP/1.1\r\n", [method uppercaseString], path];
    [requestString appendFormat:@"HOST:%@\r\n", _hostName];
    [requestString appendFormat:@"User-Agent:RealReachability\r\n"];
    [requestString appendFormat:@"Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7\r\n\r\n"];
    packet = [requestString dataUsingEncoding:NSUTF8StringEncoding];
  
    // Send the packet.
    
    if (self.socket == NULL) {
        bytesSent = -1;
        err = EBADF;
    } else {
        bytesSent = send(
                           CFSocketGetNative(self.socket),
                           packet.bytes,
                           packet.length,
                           0
                         );
        err = 0;
        if (bytesSent < 0) {
            err = errno;
        }
    }
    
    // Handle the results of the send.
    
    strongDelegate = self.delegate;
    if ( (bytesSent > 0) && (((NSUInteger) bytesSent) == packet.length) ) {
        
        // Complete success.  Tell the client.
        
        if ( (strongDelegate != nil) && [strongDelegate respondsToSelector:@selector(pingFoundation:didSendPacket:sequenceNumber:)] ) {
            [strongDelegate pingFoundation:self didSendPacket:packet sequenceNumber:self.nextSequenceNumber];
        }
    } else {
        NSError *   error;
        
        // Some sort of failure.  Tell the client.
        
        if (err == 0) {
            err = ENOBUFS;          // This is not a hugely descriptor error, alas.
        }
        error = [NSError errorWithDomain:NSPOSIXErrorDomain code:err userInfo:nil];
        if ( (strongDelegate != nil) && [strongDelegate respondsToSelector:@selector(pingFoundation:didFailToSendPacket:sequenceNumber:error:)] ) {
            [strongDelegate pingFoundation:self didFailToSendPacket:packet sequenceNumber:self.nextSequenceNumber error:error];
        }
    }
    
    self.nextSequenceNumber += 1;
    if (self.nextSequenceNumber == 0) {
        self.nextSequenceNumberHasWrapped = YES;
    }
}

/*! Calculates the offset of the ICMP header within an IPv4 packet.
 *  \details In the IPv4 case the kernel returns us a buffer that includes the
 *      IPv4 header.  We're not interested in that, so we have to skip over it.
 *      This code does a rough check of the IPv4 header and, if it looks OK,
 *      returns the offset of the ICMP header.
 *  \param packet The IPv4 packet, as returned to us by the kernel.
 *  \returns The offset of the ICMP header, or NSNotFound.
 */

+ (NSUInteger)icmpHeaderOffsetInIPv4Packet:(NSData *)packet {
    // Returns the offset of the ICMPv4Header within an IP packet.
    NSUInteger                  result;
    const struct IPv4Header *   ipPtr;
    size_t                      ipHeaderLength;
    
    result = NSNotFound;
    if (packet.length >= (sizeof(IPv4Header) + sizeof(ICMPHeader))) {
        ipPtr = (const IPv4Header *) packet.bytes;
        if ( ((ipPtr->versionAndHeaderLength & 0xF0) == 0x40) &&            // IPv4
            ( ipPtr->protocol == IPPROTO_ICMP ) ) {
            ipHeaderLength = (ipPtr->versionAndHeaderLength & 0x0F) * sizeof(uint32_t);
            if (packet.length >= (ipHeaderLength + sizeof(ICMPHeader))) {
                result = ipHeaderLength;
            }
        }
    }
    return result;
}

/*! Checks whether the specified sequence number is one we sent.
 *  \param sequenceNumber The incoming sequence number.
 *  \returns YES if the sequence number looks like one we sent.
 */

- (BOOL)validateSequenceNumber:(uint16_t)sequenceNumber {
    if (self.nextSequenceNumberHasWrapped) {
        // If the sequence numbers have wrapped that we can't reliably check
        // whether this is a sequence number we sent.  Rather, we check to see
        // whether the sequence number is within the last 120 sequence numbers
        // we sent.  Note that the uint16_t subtraction here does the right
        // thing regardless of the wrapping.
        //
        // Why 120?  Well, if we send one ping per second, 120 is 2 minutes, which
        // is the standard "max time a packet can bounce around the Internet" value.
        return ((uint16_t) (self.nextSequenceNumber - sequenceNumber)) < (uint16_t) 120;
    } else {
        return sequenceNumber < self.nextSequenceNumber;
    }
}

/*! Checks whether an incoming IPv4 packet looks like a ping response.
 *  \details This routine modifies this `packet` data!  It does this for two reasons:
 *
 *      * It needs to zero out the `checksum` field of the ICMPHeader in order to do
 *          its checksum calculation.
 *
 *      * It removes the IPv4 header from the front of the packet.
 *  \param packet The IPv4 packet, as returned to us by the kernel.
 *  \param sequenceNumberPtr A pointer to a place to start the ICMP sequence number.
 *  \returns YES if the packet looks like a reasonable IPv4 ping response.
 */

- (BOOL)validatePing4ResponsePacket:(NSMutableData *)packet sequenceNumber:(uint16_t *)sequenceNumberPtr {
    BOOL                result;
    NSUInteger          icmpHeaderOffset;
    ICMPHeader *        icmpPtr;
    uint16_t            receivedChecksum;
    uint16_t            calculatedChecksum;
    
    result = NO;
    
    icmpHeaderOffset = [[self class] icmpHeaderOffsetInIPv4Packet:packet];
    if (icmpHeaderOffset != NSNotFound) {
        icmpPtr = (struct ICMPHeader *) (((uint8_t *) packet.mutableBytes) + icmpHeaderOffset);
        
        receivedChecksum   = icmpPtr->checksum;
        icmpPtr->checksum  = 0;
        calculatedChecksum = in_cksum(icmpPtr, packet.length - icmpHeaderOffset);
        icmpPtr->checksum  = receivedChecksum;
        
        if (receivedChecksum == calculatedChecksum) {
            if ( (icmpPtr->type == ICMPv4TypeEchoReply) && (icmpPtr->code == 0) ) {
                if ( OSSwapBigToHostInt16(icmpPtr->identifier) == self.identifier ) {
                    uint16_t    sequenceNumber;
                    
                    sequenceNumber = OSSwapBigToHostInt16(icmpPtr->sequenceNumber);
                    if ([self validateSequenceNumber:sequenceNumber]) {
                        
                        // Remove the IPv4 header off the front of the data we received, leaving us with
                        // just the ICMP header and the ping payload.
                        [packet replaceBytesInRange:NSMakeRange(0, icmpHeaderOffset) withBytes:NULL length:0];
                        
                        *sequenceNumberPtr = sequenceNumber;
                        result = YES;
                    }
                }
            }
        }
    }
    
    return result;
}

/*! Checks whether an incoming IPv6 packet looks like a ping response.
 *  \param packet The IPv6 packet, as returned to us by the kernel; note that this routine
 *      could modify this data but does not need to in the IPv6 case.
 *  \param sequenceNumberPtr A pointer to a place to start the ICMP sequence number.
 *  \returns YES if the packet looks like a reasonable IPv4 ping response.
 */

- (BOOL)validatePing6ResponsePacket:(NSMutableData *)packet sequenceNumber:(uint16_t *)sequenceNumberPtr {
    BOOL                    result;
    const ICMPHeader *      icmpPtr;
    
    result = NO;
    
    if (packet.length >= sizeof(*icmpPtr)) {
        icmpPtr = packet.bytes;
        
        // In the IPv6 case we don't check the checksum because that's hard (we need to
        // cook up an IPv6 pseudo header and we don't have the ingredients) and unnecessary
        // (the kernel has already done this check).
        
        if ( (icmpPtr->type == ICMPv6TypeEchoReply) && (icmpPtr->code == 0) ) {
            if ( OSSwapBigToHostInt16(icmpPtr->identifier) == self.identifier ) {
                uint16_t    sequenceNumber;
                
                sequenceNumber = OSSwapBigToHostInt16(icmpPtr->sequenceNumber);
                if ([self validateSequenceNumber:sequenceNumber]) {
                    *sequenceNumberPtr = sequenceNumber;
                    result = YES;
                }
            }
        }
    }
    return result;
}

/*! Checks whether an incoming packet looks like a ping response.
 *  \param packet The packet, as returned to us by the kernel; note that may end up modifying
 *      this data.
 *  \param sequenceNumberPtr A pointer to a place to start the ICMP sequence number.
 *  \returns YES if the packet looks like a reasonable IPv4 ping response.
 */

- (BOOL)validatePingResponsePacket:(NSMutableData *)packet sequenceNumber:(uint16_t *)sequenceNumberPtr {
    BOOL        result;
    
    switch (self.hostAddressFamily) {
        case AF_INET: {
            result = [self validatePing4ResponsePacket:packet sequenceNumber:sequenceNumberPtr];
        } break;
        case AF_INET6: {
            result = [self validatePing6ResponsePacket:packet sequenceNumber:sequenceNumberPtr];
        } break;
        default: {
            assert(NO);
            result = NO;
        } break;
    }
    return result;
}

- (void)connect:(BOOL)success {
    if (success) {
        // Done connected, we can notify upper layer to send data.
        id<PingFoundationDelegate> strongDelegate = self.delegate;
        if ( (strongDelegate != nil) && [strongDelegate respondsToSelector:@selector(pingFoundation:didStartWithAddress:httpMode:)] ) {
            [strongDelegate pingFoundation:self didStartWithAddress:self.hostAddress httpMode:self.httpMode];
        }
    } else {
         [self didFailWithError:[NSError errorWithDomain:(NSString *)kCFErrorDomainCFNetwork code:kCFURLErrorCannotConnectToHost userInfo:nil]];
    }
}
            
/*! Reads data from the ICMP socket.
 *  \details Called by the socket handling code (SocketReadCallback) to process an ICMP
 *      message waiting on the socket.
 */

- (void)readData {
    int                     err;
    struct sockaddr_storage addr;
    socklen_t               addrLen;
    ssize_t                 bytesRead;
    void *                  buffer;
    enum { kBufferSize = 65535 };
    
    // 65535 is the maximum IP packet size, which seems like a reasonable bound
    // here (plus it's what <x-man-page://8/ping> uses).
    
    buffer = malloc(kBufferSize);
    if (buffer == NULL)
    {
        return;
    }
    
    // Actually read the data.  We use recvfrom(), and thus get back the source address,
    // but we don't actually do anything with it.  It would be trivial to pass it to
    // the delegate but we don't need it in this example.
    
    addrLen = sizeof(addr);
    bytesRead = recvfrom(CFSocketGetNative(self.socket), buffer, kBufferSize, 0, (struct sockaddr *) &addr, &addrLen);
    err = 0;
    if (bytesRead < 0) {
        err = errno;
    }
    
    // Process the data we read.
    
    if (bytesRead > 0) {
        id<PingFoundationDelegate>  strongDelegate;
        
        strongDelegate = self.delegate;
        
        if (_httpMode) {
            char previous = (char)0;
            for (int i = 0; i < bytesRead; i++) {
                if (previous == '\r' && ((char *)buffer)[i] == '\n') {
                    // Valid split, try to parse first segment.
                    NSString* httpStatus = [[NSString alloc]initWithBytes:buffer length:i-1 encoding:kCFStringEncodingUTF8];
                    if ([httpStatus hasPrefix:@"HTTP/"]) {
                        if ( (strongDelegate != nil) && [strongDelegate respondsToSelector:@selector(pingFoundation:didReceivePingResponsePacket:sequenceNumber:)] ) {
                            [strongDelegate pingFoundation:self didReceivePingResponsePacket:nil sequenceNumber:HttpModeSequenceNumber];
                        }
                    } else {
                        if ( (strongDelegate != nil) && [strongDelegate respondsToSelector:@selector(pingFoundation:didReceiveUnexpectedPacket:)] ) {
                            [strongDelegate pingFoundation:self didReceiveUnexpectedPacket:nil];
                        }
                    }
                    break;
                }
                previous = ((char *)buffer)[i];
            }
        } else {
            uint16_t                sequenceNumber;
            NSMutableData *         packet;
            
            packet = [NSMutableData dataWithBytes:buffer length:(NSUInteger) bytesRead];
            // We got some data, pass it up to our client.
            
            if ( [self validatePingResponsePacket:packet sequenceNumber:&sequenceNumber] ) {
                if ( (strongDelegate != nil) && [strongDelegate respondsToSelector:@selector(pingFoundation:didReceivePingResponsePacket:sequenceNumber:)] ) {
                    [strongDelegate pingFoundation:self didReceivePingResponsePacket:packet sequenceNumber:sequenceNumber];
                }
            } else {
                if ( (strongDelegate != nil) && [strongDelegate respondsToSelector:@selector(pingFoundation:didReceiveUnexpectedPacket:)] ) {
                    [strongDelegate pingFoundation:self didReceiveUnexpectedPacket:packet];
                }
            }
        }
    } else {
        
        // We failed to read the data, so shut everything down.
        
        if (err == 0) {
            err = EPIPE;
        }
        [self didFailWithError:[NSError errorWithDomain:NSPOSIXErrorDomain code:err userInfo:nil]];
    }
    
    free(buffer);
    
    // Note that we don't loop back trying to read more data.  Rather, we just
    // let CFSocket call us again.
}

static void SocketCallback(CFSocketRef s, CFSocketCallBackType type, CFDataRef address, const void *data, void *info) {
    // This C routine is called by CFSocket when there's data waiting on our
    // ICMP socket.  It just redirects the call to Objective-C code.
    PingFoundation *    obj;
    
    obj = (__bridge PingFoundation *) info;
    
    if (type == kCFSocketConnectCallBack) {
        [obj connect:data == NULL ? YES : NO];
    } else if (type == kCFSocketReadCallBack) {
        [obj readData];
    }
}

/*! The callback for our CFSocket object.
 *  \details This simply routes the call to our `-readData` method.
 *  \param s See the documentation for CFSocketCallBack.
 *  \param type See the documentation for CFSocketCallBack.
 *  \param address See the documentation for CFSocketCallBack.
 *  \param data See the documentation for CFSocketCallBack.
 *  \param info See the documentation for CFSocketCallBack; this is actually a pointer to the
 *      'owning' object.
 */

static void SocketReadCallback(CFSocketRef s, CFSocketCallBackType type, CFDataRef address, const void *data, void *info) {
    // This C routine is called by CFSocket when there's data waiting on our
    // ICMP socket.  It just redirects the call to Objective-C code.
    PingFoundation *    obj;
    
    obj = (__bridge PingFoundation *) info;

    [obj readData];
}

/*! Starts the send and receive infrastructure.
 *  \details This is called once we've successfully resolved `hostName` in to
 *      `hostAddress`.  It's responsible for setting up the socket for sending and
 *      receiving pings.
 */

- (void)startWithHostAddress
{
    if (self.hostAddress == nil)
    {
        return;
    }
    
    int                     err;
    int                     fd;
    
    // Open the socket.
    
    fd = -1;
    err = 0;
    switch (self.hostAddressFamily) {
            // gzw here to decide what to use! see what is going on in iOS12! TODO:
        case AF_INET: {
            if (_httpMode) {
                fd = socket(AF_INET, SOCK_STREAM, IPPROTO_IP);
            } else {
                fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP);
            }
            if (fd < 0) {
                err = errno;
            }
        } break;
        case AF_INET6: {
            if (_httpMode) {
                fd = socket(AF_INET6, SOCK_STREAM,IPPROTO_IPV6);
            } else {
                fd = socket(AF_INET6, SOCK_DGRAM, IPPROTO_ICMPV6);
            }
            if (fd < 0) {
                err = errno;
            }
        } break;
        default: {
            err = EPROTONOSUPPORT;
        } break;
    }
    
    if (err != 0) {
        [self didFailWithError:[NSError errorWithDomain:NSPOSIXErrorDomain code:err userInfo:nil]];
    } else {
        CFSocketContext         context = {0, (__bridge void *)(self), NULL, NULL, NULL};
        CFRunLoopSourceRef      rls;
        id<PingFoundationDelegate>  strongDelegate;
        
        if (_httpMode) {
            // Wrap it in a CFSocket and schedule it on the runloop.
            self.socket = (CFSocketRef) CFAutorelease( CFSocketCreateWithNative(NULL, fd, kCFSocketConnectCallBack | kCFSocketReadCallBack, SocketCallback, &context) );
            
            CFDataRef targetAddrRef = CFDataCreate(kCFAllocatorDefault, self.hostAddress.bytes, (socklen_t) self.hostAddress.length);
            // ----连接
            CFSocketConnectToAddress(self.socket, targetAddrRef, -1);
            // Release
            CFRelease(targetAddrRef);
        } else {
            // Wrap it in a CFSocket and schedule it on the runloop.
            self.socket = (CFSocketRef) CFAutorelease( CFSocketCreateWithNative(NULL, fd, kCFSocketReadCallBack, SocketReadCallback, &context) );
        }
        // The socket will now take care of cleaning up our file descriptor.
        
        fd = -1;
        
        rls = CFSocketCreateRunLoopSource(NULL, self.socket, 0);
        
        CFRunLoopAddSource(CFRunLoopGetCurrent(), rls, kCFRunLoopDefaultMode);
        
        CFRelease(rls);
        
        if (!_httpMode) {
            strongDelegate = self.delegate;
            if ( (strongDelegate != nil) && [strongDelegate respondsToSelector:@selector(pingFoundation:didStartWithAddress:httpMode:)] ) {
                [strongDelegate pingFoundation:self didStartWithAddress:self.hostAddress httpMode:self.httpMode];
            }
        }
    }
}

/*! Processes the results of our name-to-address resolution.
 *  \details Called by our CFHost resolution callback (HostResolveCallback) when host
 *      resolution is complete.  We just latch the first appropriate address and kick
 *      off the send and receive infrastructure.
 */

- (void)hostResolutionDone {
    Boolean     resolved;
    NSArray *   addresses;
    
    // Find the first appropriate address.
    
    addresses = (__bridge NSArray *) CFHostGetAddressing(self.host, &resolved);
    if ( resolved && (addresses != nil) ) {
        resolved = false;
        for (NSData * address in addresses) {
            const struct sockaddr * addrPtr;
            
            addrPtr = (const struct sockaddr *) address.bytes;
            if ( address.length >= sizeof(struct sockaddr) ) {
                switch (addrPtr->sa_family) {
                    case AF_INET: {
                        if (self.addressStyle != PingFoundationAddressStyleICMPv6) {
                            if (_httpMode) {
                                NSMutableData* mutableAddress = [NSMutableData dataWithBytes:address.bytes length:address.length];
                                struct sockaddr_in* addrInPtr = (struct sockaddr_in*) mutableAddress.mutableBytes;
                                addrInPtr->sin_port = htons(80);
                                self.hostAddress = mutableAddress;
                            } else {
                                self.hostAddress = address;
                            }
                            resolved = true;
                        }
                    } break;
                    case AF_INET6: {
                        if (self.addressStyle != PingFoundationAddressStyleICMPv4) {
                            if (_httpMode) {
                                NSMutableData* mutableAddress = [NSMutableData dataWithBytes:address.bytes length:address.length];
                                struct sockaddr_in6* addrInPtr = (struct sockaddr_in6*) mutableAddress.mutableBytes;
                                addrInPtr->sin6_port = htons(80);
                                self.hostAddress = mutableAddress;
                            } else {
                                self.hostAddress = address;
                            }
                            resolved = true;
                        }
                    } break;
                }
            }
            if (resolved) {
                break;
            }
        }
    }
    
    // We're done resolving, so shut that down.
    
    [self stopHostResolution];
    
    // If all is OK, start the send and receive infrastructure, otherwise stop.
    
    if (resolved) {
        [self startWithHostAddress];
    } else {
        [self didFailWithError:[NSError errorWithDomain:(NSString *)kCFErrorDomainCFNetwork code:kCFHostErrorHostNotFound userInfo:nil]];
    }
}

/*! The callback for our CFHost object.
 *  \details This simply routes the call to our `-hostResolutionDone` or
 *      `-didFailWithHostStreamError:` methods.
 *  \param theHost See the documentation for CFHostClientCallBack.
 *  \param typeInfo See the documentation for CFHostClientCallBack.
 *  \param error See the documentation for CFHostClientCallBack.
 *  \param info See the documentation for CFHostClientCallBack; this is actually a pointer to
 *      the 'owning' object.
 */

static void HostResolveCallback(CFHostRef theHost, CFHostInfoType typeInfo, const CFStreamError *error, void *info) {
    // This C routine is called by CFHost when the host resolution is complete.
    // It just redirects the call to the appropriate Objective-C method.
    PingFoundation *    obj;
    
    obj = (__bridge PingFoundation *) info;
    
    if (([obj isKindOfClass:[PingFoundation class]] && typeInfo == kCFHostAddresses))
    {
        if (theHost != obj->_host)
        {
            // unmatched, do nothing.
            return;
        }
        
        if ((error != NULL) && (error->domain != 0))
        {
            [obj didFailWithHostStreamError:*error];
        }
        else
        {
            [obj hostResolutionDone];
        }
    }
}

- (void)start
{
    // If the user supplied us with an address, just start pinging that.  Otherwise
    // start a host resolution.
    
    Boolean             success;
    CFHostClientContext context = {0, (__bridge void *)(self), NULL, NULL, NULL};
    CFStreamError       streamError;
    
    self.host = (CFHostRef)CFAutorelease(CFHostCreateWithName(NULL, (__bridge CFStringRef) self.hostName));
    
    if (self.host == NULL)
    {
        // host NULL; do nothing.
        return;
    }
    
    CFHostSetClient(self.host, HostResolveCallback, &context);
    CFHostScheduleWithRunLoop(self.host, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    success = CFHostStartInfoResolution(self.host, kCFHostAddresses, &streamError);
    if (!success)
    {
        [self didFailWithHostStreamError:streamError];
    }
}

/*! Stops the name-to-address resolution infrastructure.
 */

- (void)stopHostResolution {
    // Shut down the CFHost.
    if (self.host != NULL) {
        CFHostSetClient(self.host, NULL, NULL);
        CFHostUnscheduleFromRunLoop(self.host, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
        self.host = NULL;
    }
}

/*! Stops the send and receive infrastructure.
 */

- (void)stopSocket {
    if (self.socket != NULL) {
        CFSocketInvalidate(self.socket);
        self.socket = NULL;
    }
}

- (void)stop {
    [self stopHostResolution];
    [self stopSocket];
    
    // Junk the host address on stop.  If the client calls -start again, we'll 
    // re-resolve the host name.
    
    self.hostAddress = NULL;
}

@end
