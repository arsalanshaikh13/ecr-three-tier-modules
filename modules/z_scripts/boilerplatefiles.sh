#!/bin/bash

# Define the files to create
files=("main.tf" "variables.tf" "outputs.tf")

# Loop through every directory starting from the current one
find . -type d | while read -r dir; do
    # Skip the hidden .git or .terraform directories
    if [[ "$dir" == *"/.git"* ]] || [[ "$dir" == *"/.terraform"* ]]; then
        continue
    fi

    echo "Processing directory: $dir"
    
    for file in "${files[@]}"; do
        target_file="$dir/$file"
        
        # Check if file exists to avoid overwriting
        if [ ! -f "$target_file" ]; then
            touch "$target_file"
            echo "  + Created $file"
        else
            echo "  - $file already exists, skipping."
        fi
    done
done

echo "---"
echo "Done! Terraform boilerplate initialized."