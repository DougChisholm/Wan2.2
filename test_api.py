#!/usr/bin/env python3
"""
Simple test script for the Wan 2.2 API
Tests API endpoints without running actual inference
"""

import sys
import requests
from pathlib import Path

def test_api(base_url="http://localhost:8000"):
    """Test the API endpoints"""
    print(f"Testing API at: {base_url}")
    print("=" * 60)
    
    # Test root endpoint
    print("\n1. Testing root endpoint (GET /)...")
    try:
        response = requests.get(f"{base_url}/")
        if response.status_code == 200:
            print("✓ Root endpoint working")
            print(f"  Response: {response.json()}")
        else:
            print(f"✗ Root endpoint failed with status {response.status_code}")
            return False
    except Exception as e:
        print(f"✗ Root endpoint error: {e}")
        return False
    
    # Test health endpoint
    print("\n2. Testing health endpoint (GET /health)...")
    try:
        response = requests.get(f"{base_url}/health")
        if response.status_code == 200:
            print("✓ Health endpoint working")
            print(f"  Response: {response.json()}")
        else:
            print(f"✗ Health endpoint failed with status {response.status_code}")
            return False
    except Exception as e:
        print(f"✗ Health endpoint error: {e}")
        return False
    
    # Test tasks endpoint
    print("\n3. Testing tasks endpoint (GET /tasks)...")
    try:
        response = requests.get(f"{base_url}/tasks")
        if response.status_code == 200:
            print("✓ Tasks endpoint working")
            print(f"  Response: {response.json()}")
        else:
            print(f"✗ Tasks endpoint failed with status {response.status_code}")
            return False
    except Exception as e:
        print(f"✗ Tasks endpoint error: {e}")
        return False
    
    # Test sizes endpoint
    print("\n4. Testing sizes endpoint (GET /sizes/ti2v-5B)...")
    try:
        response = requests.get(f"{base_url}/sizes/ti2v-5B")
        if response.status_code == 200:
            print("✓ Sizes endpoint working")
            print(f"  Response: {response.json()}")
        else:
            print(f"✗ Sizes endpoint failed with status {response.status_code}")
            return False
    except Exception as e:
        print(f"✗ Sizes endpoint error: {e}")
        return False
    
    print("\n" + "=" * 60)
    print("✓ All basic API tests passed!")
    print("\nNote: Generation endpoint not tested (requires model)")
    print("=" * 60)
    return True

if __name__ == "__main__":
    # Get base URL from command line or use default
    base_url = sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8000"
    
    success = test_api(base_url)
    sys.exit(0 if success else 1)
