#!/usr/bin/env python3
"""
Quick test script for the streaming TTS endpoint.
Run this after starting the backend to verify streaming works.
"""

import requests
import struct

def test_streaming_endpoint():
    """Test the /v1/audio/stream endpoint"""
    
    url = "http://localhost:8880/v1/audio/stream"
    
    # Test text
    test_text = "Hello world. This is a test of the streaming TTS system. It should segment this text into multiple chunks."
    
    payload = {
        "input": test_text,
        "voice": "en_US-lessac-high",
        "speed": 1.0
    }
    
    print(f"Testing streaming endpoint: {url}")
    print(f"Text: {test_text}")
    print(f"Voice: {payload['voice']}")
    print("-" * 80)
    
    try:
        response = requests.post(url, json=payload, stream=True)
        
        if response.status_code != 200:
            print(f"❌ Error: HTTP {response.status_code}")
            print(response.text)
            return False
        
        print(f"✅ Connection established (HTTP {response.status_code})")
        print(f"Content-Type: {response.headers.get('Content-Type')}")
        print("-" * 80)
        
        # Read and parse chunks
        buffer = bytearray()
        chunk_count = 0
        
        for data in response.iter_content(chunk_size=8192):
            buffer.extend(data)
            
            # Try to parse complete chunks
            while len(buffer) >= 16:
                # Read header
                chunk_length = struct.unpack('>I', buffer[0:4])[0]
                index = struct.unpack('>I', buffer[4:8])[0]
                text_length = struct.unpack('>I', buffer[8:12])[0]
                is_last = struct.unpack('>I', buffer[12:16])[0]
                
                # Calculate total frame size
                frame_size = 16 + text_length + (chunk_length - 12 - text_length)
                
                # Check if we have complete frame
                if len(buffer) < frame_size:
                    break
                
                # Extract text
                text = buffer[16:16+text_length].decode('utf-8')
                
                # Extract audio size
                audio_size = chunk_length - 12 - text_length
                
                chunk_count += 1
                print(f"Chunk {index}:")
                print(f"  Text: {text[:60]}{'...' if len(text) > 60 else ''}")
                print(f"  Audio size: {audio_size} bytes")
                print(f"  Is last: {is_last == 1}")
                print()
                
                # Remove parsed chunk from buffer
                buffer = buffer[frame_size:]
                
                if is_last == 1:
                    print(f"✅ Received last chunk")
                    break
        
        print("-" * 80)
        print(f"✅ Test completed successfully!")
        print(f"Total chunks received: {chunk_count}")
        return True
        
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    print("=" * 80)
    print("STREAMING TTS ENDPOINT TEST")
    print("=" * 80)
    print()
    
    # Check health first
    try:
        health = requests.get("http://localhost:8880/health", timeout=5)
        if health.status_code == 200:
            print("✅ Backend is healthy")
            print()
        else:
            print("⚠️  Backend health check failed")
            print()
    except Exception as e:
        print(f"❌ Cannot connect to backend: {e}")
        print("Make sure the backend is running: python main.py")
        exit(1)
    
    # Run test
    success = test_streaming_endpoint()
    
    print()
    if success:
        print("🎉 All tests passed!")
    else:
        print("❌ Tests failed")
        exit(1)
