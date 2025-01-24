#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Setting up Python environment...${NC}"

# Check if Python 3.12 is installed
if ! command -v python3.12 &> /dev/null; then
    echo -e "${RED}Python 3.12 is not installed. Please install it first.${NC}"
    exit 1
fi

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    echo -e "${BLUE}Creating virtual environment...${NC}"
    python3.12 -m venv venv
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to create virtual environment${NC}"
        exit 1
    fi
    echo -e "${GREEN}Virtual environment created successfully${NC}"
fi

# Activate virtual environment
echo -e "${BLUE}Activating virtual environment...${NC}"
source venv/bin/activate

# Upgrade pip
echo -e "${BLUE}Upgrading pip...${NC}"
pip install --upgrade pip

# Install requirements
echo -e "${BLUE}Installing requirements...${NC}"
pip install -r requirements.txt

if [ $? -eq 0 ]; then
    echo -e "${GREEN}All requirements installed successfully!${NC}"
    
    # Additional setup steps
    echo -e "${BLUE}Running additional setup steps...${NC}"
    
    # Create necessary directories
    mkdir -p datas/ocr_results
    
    # Generate proto files
    echo -e "${BLUE}Generating gRPC code from proto files...${NC}"
    ./proto_gen.sh
    
    echo -e "${GREEN}Setup completed successfully!${NC}"
    echo -e "${BLUE}You can now run the server with: ${GREEN}python server.py${NC}"
else
    echo -e "${RED}Failed to install requirements${NC}"
    exit 1
fi 