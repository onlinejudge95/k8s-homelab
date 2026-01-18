#!/bin/bash

install_helm_charts() {
    local repo_file="$1"

    if ! command -v yq &> /dev/null; then
        echo "Error: yq is not installed."
        exit 1
    fi

    if [ ! -f "$repo_file" ]; then
        echo "Error: $repo_file not found."
        exit 1
    fi

    # Update repositories first
    echo "Adding/Updating Helm repositories..."
    yq -r '.repos[] | [.name, .url] | @tsv' "$repo_file" | while IFS=$'\t' read -r name url; do
        if [ -n "$name" ] && [ -n "$url" ]; then
            echo "Adding repo $name from $url"
            helm repo add "$name" "$url"
        fi
    done
    helm repo update

    # Install charts
    echo "Installing/Upgrading charts..."
    yq -r '.repos[] | select(.chart != null) | [.name, .chart, .release_name, .namespace, .values] | @tsv' "$repo_file" | while IFS=$'\t' read -r repo_name chart release_name namespace values_file; do
        echo "Processing $release_name ($chart)..."
        
        cmd=(helm upgrade --install "$release_name" "$chart" --namespace "$namespace" --create-namespace)
        
        if [ -n "$values_file" ] && [ "$values_file" != "null" ]; then
             if [ -f "$values_file" ]; then
                cmd+=(-f "$values_file")
             else
                echo "Warning: Values file $values_file not found for $release_name. Skipping values file."
             fi
        fi

        echo "Running: ${cmd[*]}"
        "${cmd[@]}"
    done
}

install_helm_charts "./repos.yml"