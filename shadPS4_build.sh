#!/usr/bin/env zsh

# This gets the location that the script is being run from and moves there.
SCRIPT_DIR=${0:a:h}
cd "$SCRIPT_DIR"

# ANSI color codes
PURPLE='\033[0;35m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Detect CPU architecture
ARCH="$(uname -m)"

# Introduction
introduction() {
	echo "\n${PURPLE}This script is for creating a macOS build of ${GREEN}shadPS4${NC}\n"
	
	echo "${GREEN}Homebrew${PURPLE} and the ${GREEN}Xcode command-line tools${PURPLE} are required${NC}\n"
	
	if [[ "${ARCH}" == "arm64" ]]; then 
		echo "${PURPLE}Your CPU architecture is ${GREEN}${ARCH}${PURPLE} so ${GREEN}Rosetta${PURPLE} is also required${NC}"
		echo "${PURPLE}If you build the ${GREEN}Qt UI${PURPLE} then the ${GREEN}x86_64${PURPLE} version of ${GREEN}Homebrew${PURPLE} will also be installed${NC}\n"
	fi
	
	echo "${PURPLE}If they are not present you will be prompted to install them${NC}\n"
}

native_homebrew_check() {
	echo "${PURPLE}Checking for Homebrew...${NC}"
	if ! command -v brew &> /dev/null; then
		echo "${PURPLE}Homebrew not found. Installing Homebrew...${NC}"
		/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
		if [[ "${ARCH}" == "arm64" ]]; then 
			(echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') >> $HOME/.zprofile
			eval "$(/opt/homebrew/bin/brew shellenv)"
		elif [[ "${ARCH}" == "x86_64" ]]; then 
			(echo; echo 'eval "$(/usr/local/bin/brew shellenv)"') >> $HOME/.zprofile
			eval "$(/usr/local/bin/brew shellenv)"
		else 
			echo "${RED}Could not identify CPU architecture${NC}"
			echo "${PURPLE}Quitting script...${NC}"	
			exit 1
		fi
		
		# Check for errors
		if [ $? -ne 0 ]; then
			echo "${RED}There was an issue installing Homebrew${NC}"
			echo "${PURPLE}Quitting script...${NC}"	
			exit 1
		fi
	else
		echo "${PURPLE}Homebrew found. Updating Homebrew...${NC}"
		brew update
	fi
}

x64_homebrew_check() {
	echo "${PURPLE}Checking for x64 Homebrew...${NC}"
	if ! command -v /usr/local/bin/brew &> /dev/null; then
		echo "${PURPLE}x64 Homebrew not found. Installing x64 Homebrew...${NC}"
		
		arch -x86_64 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

		# Check for errors
		if [ $? -ne 0 ]; then
			echo "${RED}There was an issue installing x64 Homebrew${NC}"
			echo "${PURPLE}Quitting script...${NC}"	
			exit 1
		fi
	else
		echo "${PURPLE}x64 Homebrew found. Updating Homebrew...${NC}"
		arch -x86_64 /usr/local/bin/brew update
	fi
}

# Function for checking for an individual dependency
single_dependency_check() {
	if [ -d "$(brew --prefix)/opt/$1" ]; then
		echo "${GREEN}Found $1. Checking for updates...${NC}"
			brew upgrade $1
	else
		 echo "${PURPLE}Did not find $1. Installing...${NC}"
		brew install $1
	fi
}

# Install required dependencies
native_dependencies_check() {
	echo "${PURPLE}Checking for native Homebrew dependencies...${NC}"
	# Required native Homebrew packages
	deps=( clang-format cmake )
	
	for dep in $deps[@]
	do 
		single_dependency_check $dep
	done
}

qt_check() {
	if [ -d "/usr/local/opt/qt@6" ]; then
		echo "${GREEN}Found Qt6. Checking for updates...${NC}"
		arch -x86_64 /usr/local/bin/brew upgrade qt@6
	else
		echo "${PURPLE}Did not find Qt6. Installing...${NC}"
		arch -x86_64 /usr/local/bin/brew install qt@6
	fi
}

get_repo() {
	if [[ ! -d "shadPS4" ]]; then 
		echo "\n${PURPLE}Could not find source folder. Downloading....${NC}"
		git clone --recursive https://github.com/shadps4-emu/shadPS4.git
		# Check for errors
		if [ $? -ne 0 ]; then
			echo "\n${RED}There was an issue downloading the source code${NC}"
			echo "${PURPLE}Quitting script...${NC}"	
			exit 1
		fi
	fi
}

build() {
	if [[ -d "shadPS4" ]]; then
		echo "\n${PURPLE}Source code folder detected...${NC}"	
		continue_menu
		cd shadPS4
		rm -rf build
		cmake -S . -B build -DCMAKE_OSX_ARCHITECTURES=x86_64 -DENABLE_QT_GUI=$QT_OPTION
		cmake --build build --parallel$(sysctl -n hw.ncpu)
		if [[ $QT_OPTION == "ON" ]]; then
			rm -rf shadPS4.app
			mv build/shadps4.app ../shadPS4.app
		fi
		cd ..
		
		# Check for errors
		if [ $? -ne 0 ]; then
			echo "${RED}There was an issue compiling the source code${NC}"
			echo "${PURPLE}Quitting script...${NC}"	
			exit 1
		fi
	else 
		echo "${RED}Could not find source folder${NC}"
		echo "${PURPLE}Quitting...${NC}"
		exit 1
	fi
}

main_menu() {
	PS3='Which version would you like to build? '
	OPTIONS=(
		"Qt build"
		"Qt build without Homebrew checks"
		"SDL build"
		"SDL build without Homebrew checks"
		"Quit")
	select opt in $OPTIONS[@]
	do
		case $opt in
			"Qt build")
				QT_OPTION="ON"
				native_homebrew_check
				if [[ "${ARCH}" == "arm64" ]]; then 
					x64_homebrew_check
				fi
				native_dependencies_check
				qt_check
				get_repo
				build
				cleanup_menu
				break
				;;
			"Qt build without Homebrew checks")
				QT_OPTION="ON"
				echo "${RED}Skipping Homebrew checks${NC}"
				echo "${PURPLE}The script will fail if any of the dependencies are missing${NC}"
				get_repo
				build
				cleanup_menu
				break
				;;
			"SDL build")
				QT_OPTION="OFF"
				native_homebrew_check
				native_dependencies_check
				get_repo
				build
				cleanup_menu
				break
				;;
			"SDL build without Homebrew checks")
				QT_OPTION="OFF"
				echo "${RED}Skipping Homebrew checks${NC}"
				echo "${PURPLE}The script will fail if any of the dependencies are missing${NC}"
				get_repo
				build
				cleanup_menu
				break
				;;
			"Quit")
				echo "${RED}Quitting${NC}"
				exit 0
				;;
			*) 
				echo "\"$REPLY\" is not one of the options..."
				echo "Enter the number of the option and press enter to select"
				;;
		esac
	done
}

continue_menu() {
	PS3='Would you like to continue building? '
	OPTIONS=(
		"Continue"
		"Quit")
	select opt in $OPTIONS[@]
	do
		case $opt in
			"Continue")
				break
				;;
			"Quit")
				echo "${PURPLE}Quitting${NC}"
				exit 0
				;;
			*) 
				echo "\"$REPLY\" is not one of the options..."
				echo "Enter the number of the option and press enter to select"
				;;
		esac
	done
}

cleanup_menu() {
	echo "\n${GREEN}The script has completed${NC}"
	
	PS3='Would you like to delete the source folder? '
	OPTIONS=(
		"Delete"
		"Quit")
	select opt in $OPTIONS[@]
	do
		case $opt in
			"Delete")
				echo "${PURPLE}Cleaning up${NC}"
				rm -rf shadPS4
				exit 0
				;;
			"Quit")
				echo "${PURPLE}Quitting${NC}"
				exit 0
				;;
			*) 
				echo "\"$REPLY\" is not one of the options..."
				echo "Enter the number of the option and press enter to select"
				;;
		esac
	done
}

introduction
main_menu