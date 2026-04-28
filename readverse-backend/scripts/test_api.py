"""Test script for TTS API"""

import requests
import json
from pathlib import Path

BASE_URL = "http://localhost:8880"


def test_health():
    """Test health endpoint"""
    print("Testing health endpoint...")
    response = requests.get(f"{BASE_URL}/health")
    print(f"Status: {response.status_code}")
    print(f"Response: {json.dumps(response.json(), indent=2)}")
    print()


def test_list_voices():
    """Test voices list endpoint"""
    print("Testing voices list...")
    response = requests.get(f"{BASE_URL}/v1/audio/voices")
    print(f"Status: {response.status_code}")
    data = response.json()
    print(f"Total voices: {data['total']}")
    print("Available voices:")
    for voice in data['voices'][:5]:  # Show first 5
        print(f"  - {voice['id']}: {voice['name']} ({voice['language']})")
    print()


def test_generate_speech(text="Hello world! This is a test of the Piper TTS system.", voice="en_US-lessac-medium"):
    """Test speech generation"""
    print(f"Testing speech generation with voice '{voice}'...")
    
    response = requests.post(
        f"{BASE_URL}/v1/audio/speech",
        json={
            "model": "piper",
            "input": text,
            "voice": voice,
            "response_format": "mp3",
            "speed": 1.0
        }
    )
    
    print(f"Status: {response.status_code}")
    
    if response.status_code == 200:
        output_file = Path(f"test_output_{voice.replace('/', '_')}.mp3")
        output_file.write_bytes(response.content)
        print(f"Audio saved to: {output_file}")
        print(f"File size: {len(response.content)} bytes")
    else:
        print(f"Error: {response.text}")
    print()


def test_voice_mixing():
    """Test multiple voices (Piper doesn't support mixing, so test different voices)"""
    print("Testing different voices...")
    
    # Test US voice
    response1 = requests.post(
        f"{BASE_URL}/v1/audio/speech",
        json={
            "input": "This is the US male voice.",
            "voice": "en_US-lessac-medium",
            "response_format": "mp3"
        }
    )
    
    # Test GB voice
    response2 = requests.post(
        f"{BASE_URL}/v1/audio/speech",
        json={
            "input": "This is the British male voice.",
            "voice": "en_GB-alan-medium",
            "response_format": "mp3"
        }
    )
    
    print(f"US voice status: {response1.status_code}")
    print(f"GB voice status: {response2.status_code}")
    
    if response1.status_code == 200:
        output_file = Path("test_output_us.mp3")
        output_file.write_bytes(response1.content)
        print(f"US audio saved to: {output_file}")
    
    if response2.status_code == 200:
        output_file = Path("test_output_gb.mp3")
        output_file.write_bytes(response2.content)
        print(f"GB audio saved to: {output_file}")
    print()


def test_streaming():
    """Test streaming generation"""
    print("Testing streaming...")
    
    response = requests.post(
        f"{BASE_URL}/v1/audio/speech",
        json={
            "input": "This is a streaming test. The audio should be generated in chunks.",
            "voice": "en_US-lessac-medium",
            "response_format": "mp3",
            "stream": True
        },
        stream=True
    )
    
    print(f"Status: {response.status_code}")
    
    if response.status_code == 200:
        output_file = Path("test_output_streaming.mp3")
        total_bytes = 0
        
        with open(output_file, "wb") as f:
            for chunk in response.iter_content(chunk_size=1024):
                if chunk:
                    f.write(chunk)
                    total_bytes += len(chunk)
                    print(f"  Received chunk: {len(chunk)} bytes (total: {total_bytes})")
        
        print(f"Streaming audio saved to: {output_file}")
        print(f"Total size: {total_bytes} bytes")
    else:
        print(f"Error: {response.text}")
    print()


def test_long_text():
    """Test with longer text"""
    print("Testing with longer text...")
    
    long_text = """
    The Piper text-to-speech model is a powerful tool for generating natural-sounding speech.
    It uses ONNX runtime for fast inference without requiring PyTorch or heavy dependencies.
    This makes it ideal for applications where both quality and efficiency are important.
    The model supports multiple languages and voices, making it versatile for various use cases.
    Best of all, it's lightweight and runs efficiently on CPU.
    """
    
    response = requests.post(
        f"{BASE_URL}/v1/audio/speech",
        json={
            "input": long_text.strip(),
            "voice": "en_US-amy-medium",
            "response_format": "mp3",
            "speed": 1.0
        }
    )
    
    print(f"Status: {response.status_code}")
    
    if response.status_code == 200:
        output_file = Path("test_output_long.mp3")
        output_file.write_bytes(response.content)
        print(f"Long audio saved to: {output_file}")
        print(f"File size: {len(response.content)} bytes")
    else:
        print(f"Error: {response.text}")
    print()


if __name__ == "__main__":
    print("=" * 60)
    print("ReadVerse Piper TTS API Test Suite")
    print("=" * 60)
    print()
    
    try:
        test_health()
        test_list_voices()
        test_generate_speech()
        test_voice_mixing()  # Now tests different voices instead of mixing
        test_streaming()
        test_long_text()
        
        print("=" * 60)
        print("All tests completed!")
        print("=" * 60)
        
    except requests.exceptions.ConnectionError:
        print("ERROR: Could not connect to API. Make sure the server is running at", BASE_URL)
    except Exception as e:
        print(f"ERROR: {e}")
