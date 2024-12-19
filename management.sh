#!/bin/bash

# ===== CONFIGURATION =====
LOG_FILE="docker_management_log_$(date +%F).log"
LOG_DIR="./logs"
BACKUP_DIR="./backups"
DNS_SERVER="8.8.8.8"
WEB_IMAGE="nginx:latest"
DB_IMAGE="mysql:5.7"
MONITOR_IMAGE="prom/prometheus:latest"
NETWORK_NAME="app_network"
DB_PASSWORD="leapassword"

# ===== FUNCTIONS =====

log_message() {
    local message=$1
    echo "$(date +'%Y-%m-%d %H:%M:%S') | $message" | tee -a "$LOG_FILE"
}

create_directories() {
    mkdir -p "$LOG_DIR" "$BACKUP_DIR"
}

create_network() {
    if ! docker network inspect $NETWORK_NAME >/dev/null 2>&1; then
        docker network create $NETWORK_NAME
        log_message "Docker network $NETWORK_NAME created."
    else
        log_message "Docker network $NETWORK_NAME already exists."
    fi
}

start_containers() {
    log_message "Starting containers..."
    docker run -d --name web_app --network $NETWORK_NAME -p 8080:80 $WEB_IMAGE
    docker run -d --name db_server --network $NETWORK_NAME -e MYSQL_ROOT_PASSWORD=$DB_PASSWORD -p 3306:3306 $DB_IMAGE
    docker run -d --name monitoring --network $NETWORK_NAME -p 9090:9090 $MONITOR_IMAGE
    log_message "All containers started successfully."
}

stop_containers() {
    log_message "Stopping containers..."
    docker stop web_app db_server monitoring >/dev/null 2>&1
    docker rm web_app db_server monitoring >/dev/null 2>&1
    log_message "All containers stopped and removed."
}

backup_database() {
    log_message "Backing up MySQL database..."
    docker exec db_server sh -c 'exec mysqldump --all-databases -uroot -p"$MYSQL_ROOT_PASSWORD"' > "$BACKUP_DIR/db_backup_$(date +%F_%H-%M-%S).sql"
    log_message "Database backup saved to $BACKUP_DIR."
}

restore_database() {
    read -rp "Enter the backup file to restore: " backup_file
    if [[ -f "$backup_file" ]]; then
        docker exec -i db_server sh -c 'exec mysql -uroot -p"$MYSQL_ROOT_PASSWORD"' < "$backup_file"
        log_message "Database restored from $backup_file."
    else
        log_message "⚠️ Backup file not found."
    fi
}

archive_logs() {
    log_message "Archiving container logs..."
    docker logs web_app > "$LOG_DIR/web_app_$(date +%F_%H-%M-%S).log"
    docker logs db_server > "$LOG_DIR/db_server_$(date +%F_%H-%M-%S).log"
    docker logs monitoring > "$LOG_DIR/monitoring_$(date +%F_%H-%M-%S).log"
    log_message "Logs archived in $LOG_DIR."
}

export_stats() {
    log_message "Exporting container stats to stats.csv..."
    docker stats --no-stream --format "table {{.Container}},{{.CPUPerc}},{{.MemUsage}}" > stats.csv
    log_message "Docker stats exported to stats.csv."
}

check_health() {
    log_message "Checking container health..."
    for container in web_app db_server monitoring; do
        if ! docker inspect -f '{{.State.Health.Status}}' "$container" 2>/dev/null | grep -q "healthy"; then
            log_message "⚠️ $container is not healthy. Restarting..."
            docker restart "$container"
        else
            log_message "$container is healthy."
        fi
    done
}

# ===== MAIN MENU =====
main_menu() {
    while true; do
        clear
        echo "===== Docker Container Management Tool ====="
        echo "1. Start Containers"
        echo "2. Stop Containers"
        echo "3. Backup Database"
        echo "4. Restore Database"
        echo "5. Archive Logs"
        echo "6. Export Docker Stats"
        echo "7. Check Container Health"
        echo "8. Cleanup Docker Resources"
        echo "9. Exit"
        echo "==========================================="
        read -rp "Select an option: " choice

        case $choice in
            1) 
                create_network
                start_containers
                ;;
            2) 
                stop_containers
                ;;
            3) 
                backup_database
                ;;
            4) 
                restore_database
                ;;
            5) 
                archive_logs
                ;;
            6) 
                export_stats
                ;;
            7) 
                check_health
                ;;
            8) 
                docker system prune -f
                log_message "Docker cleanup completed."
                ;;
            9) 
                log_message "Exiting Docker management tool."
                exit 0
                ;;
            *) 
                echo "Invalid option. Please try again."
                ;;
        esac

        read -rp "Press Enter to return to the main menu..."
    done
}

# ===== START SCRIPT =====
create_directories
log_message "Starting Docker Management Script..."
main_menu
