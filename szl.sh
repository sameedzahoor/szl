#!/bin/bash

# szl is a tiny terminal interface for chatting with llms (uses python-tgpt and fzf).

# ANSI shortcuts
BOLD_RED='\033[1;31m'
BOLD_GREEN='\033[1;32m'
BOLD_YELLOW='\033[1;33m'
BOLD_CYAN='\033[1;36m'
BOLD_PURPLE='\033[1;35m'
BOLD_BLUE='\033[1;34m'
BOLD_DARKGREY='\033[1;30m'

BOLD='\033[1m'
NO_COLOR='\033[0m'

CANCEL_NEWLINE='\c'
ERASE_LINE='\r\033[K\033[A'

# Error if any arguments are present
if [ "$#" -gt 0 ]; then
	echo "${BOLD_RED}Error: This command does not accept any arguments.${NO_COLOR}"
	exit 1
fi

# Setting up default files and directories. Uncomment the echo lines for verbose output.
default_directory="$HOME/.szl"
if [ ! -d "$default_directory" ]; then
	# echo -e "${BOLD_YELLOW}Creating default directory at $default_directory${NO_COLOR}"
	mkdir "$default_directory"
fi
shell_prompt_history="$default_directory/shell_prompt_history"
if [ ! -f "$shell_prompt_history" ]; then
	# echo -e "${BOLD_YELLOW}Creating history file for prompts at $shell_prompt_history${NO_COLOR}"
	touch "$shell_prompt_history"
fi
shell_cmd_history="$default_directory/shell_cmd_history"
if [ ! -f "$shell_cmd_history" ]; then
	# echo -e "${BOLD_YELLOW}Creating history file for commands at $shell_cmd_history${NO_COLOR}"
	touch "$shell_cmd_history"
fi

chat_directory=$default_directory/chats
if [ ! -d "$chat_directory" ]; then
	# echo -e "${BOLD_YELLOW}Creating directory for storing chats at $chat_directory${NO_COLOR}"
	mkdir "$chat_directory"
fi
current_chat_file="$chat_directory/current_chat_file.txt"

regular_prompt_history="$default_directory/regular_prompt_history"
if [ ! -f "$regular_prompt_history" ]; then
	# echo -e "${BOLD_YELLOW}Creating history file for prompts at $regular_prompt_history${NO_COLOR}"
	touch "$regular_prompt_history"
fi

# List of available providers
available_providers=$(cat << 'EOF'
fakeopen
opengpt
koboldai
Aura
Bing
ChatgptAi
ChatgptDemo
FakeGpt
GeminiProChat
Koala
Liaobots
Llama2
Phind
You
EOF
)

# Display current provider
current_provider="Aura"
current_provider_for_shell="fakeopen"

# Set default szl mode
current_mode="regular"

# Set code theme
current_code_theme="monokai"
raw_flag="--raw"

# Default llm settings
max_tokens_sample=600
temperature=0.2
top_k=-1.0
top_p=0.999


# Help menu
help_menu=$(cat << 'EOF'
------------------------------------szl help--------------------------------------

Menu keys :

Accept typed input      <Enter>
Accept entry from menu  <Tab>
Cancel                  <Esc>

Type and accept the following commands in szl to execute the corresponding actions.

Actions available                                                 Default Commands

Exit szl                                                         :exit | :q | exit
Inspect Mode (Unfreeze fzf)                                      :inspect | :i | i
Switch to regular chat mode                                          :regular | :r
Switch to shell mode                                                   :shell | :s
Switch to code mode                                                     :code | :c
Delete last query from current selected chat             :delete_last_query | :dlq
Begin new chat                                                           :new | :n
Switch to existing chat                                        :switch_chat | :swc
Save current chat                                                            :save
Delete existing chat                                           :delete_chat | :del
Select provider from menu                                           :provider | :p
Launch bash within szl                                                       :bash
Launch zsh within szl                                                         :zsh
Show help menu                                                           :help | ?
Toggle raw/prettify text                                        :toggle_raw | :tor

EOF
)

# Built-in default commands for szl
handle_default_commands_text=$(cat << 'EOF'
case "$text_input" in
    
	# Handles pressing <Esc> at the prompt 
    	"")
        	return
    	;;
    
	# Exit from szl    
    	"exit"|":exit"|":q")
        	exit 0
    	;;
	
	# Show help menu
	":help"|"?")
		echo -e "${BOLD_CYAN}[] ${NO_COLOR}"
		echo -e "$help_menu"
		return
	;;
    
	# Inspect mode for unfreezing fzf to enable mouse scrolling and copying text
    	":inspect"|":i"|"i")
        	read -s -n 1
        	return
    	;;
    
	# Switch to regular mode
    	":regular"|":r")
        	current_mode="regular"
		echo -e "${BOLD_CYAN}[] ${NO_COLOR}"
		echo "Switched to regular mode".		
        	return
	;;
    
	# Switch to code mode
    	":code"|":c")
        	current_mode="code"
		echo -e "${BOLD_CYAN}[] ${NO_COLOR}"
		echo "Switched to code mode."		
        	return
    	;;
    
	# Switch to shell mode
    	":shell"|":s")
        	current_mode="shell"
		echo -e "${BOLD_CYAN}[] ${NO_COLOR}"
		echo "Switched to shell mode. Saving conversations is disabled in this mode." 
		echo "Default provider for this mode is $current_provider_for_shell."
        	return
    	;;
	
	# Delete last query and response in the current chat
	":delete_last_query"|":dlq")
		if [ ! -f "$current_chat_file" ]; then
			return
		fi
		line_no=$(grep -n "^User :" "$current_chat_file" | tail -n 1 | sed 's/:.*//')
		# sed -i "" "${line_no},\$d" "$current_chat_file"	# For mac users
		sed -i "${line_no},\$d" "$current_chat_file"	# For linux users
		echo -e "${BOLD_CYAN}[] ${NO_COLOR}"		
		echo 'Deleted the last question and response in the current selected conversation.'
		return
	;;
	
	# Switch current chat
	":switch_chat"|":swc")
		echo -e "${BOLD_CYAN}[] ${NO_COLOR}"
		echo -e "${BOLD_YELLOW}Select an existing chat:${NO_COLOR}${CANCEL_NEWLINE}"
		selected_chat="$(ls -t $chat_directory | sed 's/\.txt$//' | fzf --layout=reverse --height=10% --prompt='> ' --pointer="- " --info="right" --query="" --bind=enter:accept,tab:accept)"
		echo -e "${ERASE_LINE}"
		if [ "$selected_chat" = "" ]; then
			echo "No chat selected."
			return
		fi
		current_chat_file="$chat_directory/$selected_chat.txt"
		echo -e "Current selected chat is ${BOLD_YELLOW}$selected_chat${NO_COLOR}"
		return	
	;;
	
	# Read existing chat
	":read"|":rd")
		echo -e "${BOLD_CYAN}[] ${NO_COLOR}"
		echo -e "${BOLD_YELLOW}Select an existing chat to read:${NO_COLOR}${CANCEL_NEWLINE}"
		selected_chat="$(ls -t $chat_directory | sed 's/\.txt$//' | fzf --layout=reverse --height=10% --prompt='> ' --pointer="- " --info="right" --query="" --bind=enter:accept,tab:accept)"
		echo -e "${ERASE_LINE}"
		if [ "$selected_chat" = "" ]; then
			echo "No chat selected."
			return
		fi
		echo -e "Reading chat named ${BOLD_YELLOW}$selected_chat${NO_COLOR}"
		printf "$(sed 's/^User :/\\033[1;31m>\\033[0m\n/'  "$chat_directory/$selected_chat.txt" | sed 's/^LLM :/\\033[1;32m><\\033[0m\n/' | sed "1{/You're a Large Language Model for chatting with people. Your role: Provide ONLY response./d;}")" | less -R
		return	
	;;
	
	# Delete existing chat
	":delete_chat"|":del")
		echo -e "${BOLD_CYAN}[] ${NO_COLOR}"
		echo -e "${BOLD_YELLOW}Select an existing chat to delete:${NO_COLOR}${CANCEL_NEWLINE}"
		selected_chat="$(ls -t $chat_directory | sed 's/\.txt$//' | fzf --layout=reverse --height=10% --prompt='> ' --pointer="- " --info="right" --query="" --bind=enter:accept,tab:accept)"
		echo -e "${ERASE_LINE}"
		if [ "$selected_chat" = "" ]; then
			echo "Operation cancelled."
			return
		elif [ "$selected_chat" = "$current_chat_file" ]; then
			current_chat_file="$chat_directory/current_chat_file.txt"
			echo "Starting new chat."
		fi
		echo -e "Deleted chat named ${BOLD_RED}$selected_chat${NO_COLOR}"
		rm "$chat_directory/${selected_chat}.txt"
		return	
	;;
	
	# Save current chat
	":save")
		echo -e "${BOLD_CYAN}[] ${NO_COLOR}"
		echo -e "${BOLD_YELLOW}Save chat as:${NO_COLOR}${CANCEL_NEWLINE}"	
		selected_chat="$(echo "" | fzf --layout=reverse --height=10% --pointer="- " --info="right" --bind=enter:print-query)"
		echo -e "${ERASE_LINE}"	
		if [ "$selected_chat" = "" ]; then
			echo -e "${BOLD_RED}Invalid filename${NO_COLOR}"
		elif [ -f "$selected_chat.txt" ]; then
			echo -e "${BOLD_YELLOW}Chat file already exists by this name. Choose a different filename.${NO_COLOR}"
		else
			cp "$current_chat_file" "$chat_directory/$selected_chat.txt"
			current_chat_file="$chat_directory/$selected_chat.txt"
			echo -e "File saved as ${BOLD_YELLOW}$selected_chat${NO_COLOR}"
		fi
		return
	;;
	
	# Begin new chat
	":new"|":n")
		# New chat menu
		echo -e "${BOLD_CYAN}[] ${NO_COLOR}"
		echo -e "${BOLD_YELLOW}Provide a name for the newchat or use <tab> to select an option below.${NO_COLOR}${CANCEL_NEWLINE}"
		initiate_chat="$(echo -e "Begin a new chat without saving it" | fzf --layout=reverse --height=10% --prompt='> ' --pointer="- " --info="right" --query="" --bind=enter:print-query,tab:accept)"
		echo -e "${ERASE_LINE}"
		if [ "$initiate_chat" = "Begin a new chat without saving it" ]; then
			if [ -f "$chat_directory/current_chat_file.txt" ]; then
				rm "$chat_directory/current_chat_file.txt"
			fi
			current_chat_file="$chat_directory/current_chat_file.txt"
			echo "Starting new chat."

		# Handle empty input or cancel
		elif [ "$initiate_chat" = "" ]; then
			echo -e "${BOLD_YELLOW}No filename entered.${NO_COLOR}"

		# Rejoin existing chat in case of repeated filename
		elif [ -f "$chat_directory/${initiate_chat}.txt" ]; then
			echo -e "${BOLD_YELLOW}The file called $initiate_chat already exists.${NO_COLOR}"
			echo "Switching to this chat file."
			current_chat_file="$chat_directory/${initiate_chat}.txt"

		# Start a fresh chat
		else
			echo -e "Starting new chat named ${BOLD_YELLOW}$initiate_chat.${NO_COLOR}"
			current_chat_file="$chat_directory/${initiate_chat}.txt"	
		fi
		
		return
	;;
    
	# Launch bash within szl
    	":bash")
        	bash
        	return
    	;;
    
	# Launch zsh within szl
    	":zsh")
        	zsh
        	return
    	;;
	
	# Switch model provider
	":provider"|":p")
		new_provider=$(echo "$available_providers" | fzf --layout=reverse --height=10% --pointer="- " --info="right" --bind=tab:accept)
		if [ "$new_provider" != "" ]; then
			current_provider="$new_provider"
			echo -e "${BOLD_CYAN}[] ${NO_COLOR}"
			echo "Switched provider to $current_provider."
		fi
		return
	;;
	
	# Toggle raw flag
	":toggle_raw"|":tor")
		echo -e "${BOLD_CYAN}[] ${NO_COLOR}"
		if [ "$raw_flag" = "--raw" ]; then
			raw_flag="--prettify"
			echo "Disabling output format 'raw'."
		elif [ "$raw_flag" = "--prettify" ]; then
			raw_flag="--raw"
			echo "Enabling output format 'raw'."
		fi
		return
	;;
esac
EOF
)

handle_default_commands_shell=$(echo "$handle_default_commands_text" | sed 's/text_input/shell_input/g')

# The szl regular prompt
szl_regular_prompt() {

	# The text prompt.
	text_input="$(tac $regular_prompt_history | awk '!seen[$0]++' | fzf --layout=reverse --height=10% --pointer="- " --info="right" --query="" --bind=enter:print-query,tab:accept)"
	
	# Handling default commands
	eval "$handle_default_commands_text"

	# Confirmation dialog for text prompt
	echo -e "${BOLD_YELLOW}Confirm prompt:${NO_COLOR}${CANCEL_NEWLINE}"
	text_input="$(echo "" | fzf --layout=reverse --height=10% --pointer="- " --info="right" --query="$text_input" --bind=enter:print-query)"
	echo -e "${ERASE_LINE}"

	# Handling default commands
	eval "$handle_default_commands_text"

	# Print output and update text prompt history
	echo -e "${BOLD_RED}> ${NO_COLOR}"
	echo -e "${BOLD}$text_input${NO_COLOR}"
	echo "$text_input" >> "$regular_prompt_history"

	# Generate response
	echo -e "${BOLD_GREEN}>< ${NO_COLOR}"

	if [ "$current_mode" = "code" ]; then
		pytgpt generate $raw_flag --quiet --code --code-theme="$current_code_theme"  --temperature "$temperature" --top-p  "$top_p" --top-k "$top_k" --max-tokens "$max_tokens_sample" --provider "$current_provider" --filepath "$current_chat_file" "$text_input" # For python-tgpt
	else	
		pytgpt generate $raw_flag --quiet --temperature "$temperature" --top-p  "$top_p" --top-k "$top_k" --max-tokens "$max_tokens_sample" --provider "$current_provider" --filepath "$current_chat_file" "$text_input" # For python-tgpt
	fi
	
	# Unfreeze terminal from fzf to inspect output and mouse scroll
	read -s -n 1

	return
}

# The szl shell prompt
szl_shell_prompt() {

	# The text prompt.
	text_input="$(tac $shell_prompt_history | awk '!seen[$0]++' | fzf --layout=reverse --height=10% --pointer="- " --info="right" --query="" --bind=enter:print-query,tab:accept)"
	
	# Handling default commands
	eval "$handle_default_commands_text"

	# Confirmation dialog for text prompt
	echo -e "${BOLD_YELLOW}Confirm prompt:${NO_COLOR}${CANCEL_NEWLINE}"
	text_input="$(echo "" | fzf --layout=reverse --height=10% --pointer="- " --info="right" --query="$text_input" --bind=enter:print-query,tab:accept)"
	echo -e "${ERASE_LINE}"

	# Handling default commands
	eval "$handle_default_commands_text"

	# Update text prompt history
	echo -e "${BOLD_RED}> ${NO_COLOR}"
	echo -e "${BOLD}$text_input${NO_COLOR}"
	echo "$text_input" >> "$shell_prompt_history"

	# Post process the prompt for shell syntax	
	text_input=$(echo $text_input |  sed 'a\Respond in a single line with ONLY THE CODE (do not put the code in quotation marks). No explanations, formatting, markdown etc. ONLY THE COMMAND. You are allowed to chain commands using semi-colon shell syntax to fit the code in a single line.')

	# The command prompt
	shell_input="$(pytgpt generate --shell --quiet --temperature "$temperature" --top-p  "$top_p" --top-k "$top_k" --max-tokens "$max_tokens_sample" --disable-conversation --provider "$current_provider_for_shell" "$text_input" | sed 's/[[:space:]]*$//' | fzf --layout=reverse --height=10% --prompt='> ' --pointer="- " --query="" --info="default" --bind=enter:print-query,tab:accept)"

	# Handling default commands
	eval "$handle_default_commands_shell"

	# Confirmation dialog for command prompt
	echo -e "${BOLD_YELLOW}Confirm command:${NO_COLOR}${CANCEL_NEWLINE}"
	shell_input="$(tac "$shell_cmd_history" | awk '!seen[$0]++' | fzf --layout=reverse --height=10% --prompt='> ' --pointer="> " --info="right" --query="$shell_input" --bind=enter:print-query,tab:accept)"
	echo -e "${ERASE_LINE}"

	echo "$shell_input"
	# Handling default commands
	eval "$handle_default_commands_shell"

	# Update text prompt history
	echo -e "${BOLD_GREEN}>< ${BOLD_RED}> ${NO_COLOR}"
	echo -e "${BOLD}$shell_input${NO_COLOR}"	

	# Final confirmation for run followed by execution
	echo -e "${BOLD_CYAN}[] ${NO_COLOR}"
	echo -e "${BOLD_CYAN}Execute?${NO_COLOR}"
	while true; do
		read -r -s -n 1 key

		# Check for escape key
		if [ "$key" = $'\x1b' ]; then
			echo -e "${BOLD_RED}> ${NO_COLOR}"
			echo -e "${BOLD_YELLOW}No. Cancel execution.${NO_COLOR}"
			break

		# Check for return or spacebar
		elif [ -z "$key" ]; then

			# Update command history
			echo "$shell_input" >> "$shell_cmd_history"
			
			echo -e "${BOLD_RED}> ${NO_COLOR}"
			echo -e "${BOLD_GREEN}Yes. Go ahead and execute.${NO_COLOR}"
			echo -e "${BOLD_YELLOW}!! ${NO_COLOR}"
			eval "$shell_input" #2>&1
			exit_code=$?

			echo -e "${BOLD_CYAN}[] ${NO_COLOR}"
			
			if [ $exit_code -eq 0 ]; then
				echo -e "${BOLD_GREEN}Done.${NO_COLOR}"
			else
				echo -e "${BOLD_RED}Errors were encountered during execution. Aborting.${NO_COLOR}"
			fi
			
			# Unfreeze terminal from fzf to facilitate inspecting output on terminal and mouse scroll
			read -s -n 1

			break

		else
			echo -e "${BOLD_YELLOW}Invalid input. Press <Enter> or <Space> to continue or <Esc> to abort.${NO_COLOR}"
		fi
	done
	return
}

# Main script

# Start a new chat or load an existing one from the menu
echo -e "${BOLD_YELLOW}Provide a name for the newchat or use <tab> to select an option below.${NO_COLOR}${CANCEL_NEWLINE}"
initiate_chat="$(echo -e "Begin a new chat without saving it\nContinue an existing chat" | fzf --layout=reverse --height=10% --prompt='> ' --pointer="- " --info="right" --query="" --bind=enter:print-query,tab:accept)"
echo -e "${ERASE_LINE}"

# Begin temporary chat
if [ "$initiate_chat" = "Begin a new chat without saving it" ]; then
	if [ -f "$current_chat_file" ]; then
		rm "$current_chat_file"
	fi
	echo -e "${BOLD_CYAN}[] ${NO_COLOR}"
	echo "Starting new chat."

# Handle empty input or cancel
elif [ "$initiate_chat" = "" ]; then
	echo -e "${BOLD_CYAN}[] ${NO_COLOR}"
	echo -e "${BOLD_YELLOW}No filename entered. Exiting.${NO_COLOR}"
	exit 0

# Rejoin existing chat in case of repeated filename
elif [ -f "$chat_directory/${initiate_chat}.txt" ]; then
	echo -e "${BOLD_CYAN}[] ${NO_COLOR}"
	echo -e "${BOLD_YELLOW}The file called $initiate_chat already exists.${NO_COLOR}"
	echo "Switching to this chat file."
	current_chat_file="$chat_directory/${initiate_chat}.txt"

# Continue an existing chat	
elif [ "$initiate_chat" = "Continue an existing chat" ]; then
	echo -e "${BOLD_YELLOW}Select an existing chat:${NO_COLOR}${CANCEL_NEWLINE}"
	selected_chat="$(ls -t $chat_directory | sed 's/\.txt//' | fzf --layout=reverse --height=10% --prompt='> ' --pointer="- " --info="right" --query="" --bind=enter:accept,tab:accept)"
	echo -e "${ERASE_LINE}"
	if [ "$selected_chat" = "" ]; then
		echo -e "${BOLD_CYAN}[] ${NO_COLOR}"
		echo -e "${BOLD_YELLOW}Invalid or no input. Exiting.${NO_COLOR}"
		exit 0
	fi
	current_chat_file="$chat_directory/${selected_chat}.txt"
	echo -e "${BOLD_CYAN}[] ${NO_COLOR}"
	echo -e "Continuing existing chat named ${BOLD_YELLOW}$selected_chat${NO_COLOR}"

# Start a fresh chat
else
	echo -e "${BOLD_CYAN}[] ${NO_COLOR}"
	echo -e "Starting new chat named ${BOLD_YELLOW}$initiate_chat.${NO_COLOR}"
	current_chat_file="$chat_directory/${initiate_chat}.txt"	
fi

# szl greeting
echo -e "${BOLD_CYAN}[] ${NO_COLOR}"
echo "Welcome to the szl prompt, a terminal interface to chat with LLM's using pytgpt."
echo "Enter the prompt for the LLM below."
echo -e "\nUse <enter> to accept the typed prompts."
echo "Use <tab> to accept options from menu."

# Display help option
echo -e "\nFor help enter '?'."

# Print out the current provider
echo "The current provider for the LLM is $current_provider."

while true; do
	if [ "$current_mode" = "shell" ]; then
		szl_shell_prompt
	else
		szl_regular_prompt
	fi
done
