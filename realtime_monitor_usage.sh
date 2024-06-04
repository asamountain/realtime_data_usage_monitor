#!/bin/bash

# Function to calculate data usage
calculate_usage() {
  initial_received=$(netstat -ib | grep -m 1 en0 | awk '{print $7}')
  initial_sent=$(netstat -ib | grep -m 1 en0 | awk '{print $10}')

  sleep 1  # Wait for 1 second

  final_received=$(netstat -ib | grep -m 1 en0 | awk '{print $7}')
  final_sent=$(netstat -ib | grep -m 1 en0 | awk '{print $10}')

  received_bytes=$(($final_received - $initial_received))
  sent_bytes=$(($final_sent - $initial_sent))

  received_kb=$(echo "scale=3; $received_bytes / 1024" | bc)
  sent_kb=$(echo "scale=3; $sent_bytes / 1024" | bc)
  total_kb=$(echo "scale=3; $received_kb + $sent_kb" | bc)

  received_gb=$(echo "scale=3; $received_bytes / 1073741824" | bc)
  sent_gb=$(echo "scale=3; $sent_bytes / 1073741824" | bc)
  total_gb=$(echo "scale=3; $received_gb + $sent_gb" | bc)

  echo "$received_gb $sent_gb $total_gb $received_kb $sent_kb $total_kb"
}

# Trap to handle termination signals
trap "echo 'Script interrupted.'; exit" SIGINT SIGTERM

total_received_gb=0
total_sent_gb=0
total_usage_gb=0
total_received_kb=0
total_sent_kb=0
total_usage_kb=0
minute_count=0

monthly_limit_gb=11
daily_limit_gb=$(echo "scale=3; $monthly_limit_gb / 30" | bc)
weekly_limit_gb=$(echo "scale=3; $monthly_limit_gb / 4" | bc)

# File to store usage data
usage_file="realtime_usage_data.csv"
echo "Second,Received_GB,Sent_GB,Total_GB,Received_KB,Sent_KB,Total_KB,Daily_Usage_GB,Weekly_Usage_GB,Monthly_Usage_GB,Daily_Usage_Percent,Weekly_Usage_Percent,Monthly_Usage_Percent" > $usage_file

# Define a threshold for significant data usage (in KB)
threshold_kb=100

while true; do
  usage=$(calculate_usage)
  received_gb=$(echo $usage | awk '{print $1}')
  sent_gb=$(echo $usage | awk '{print $2}')
  total_gb=$(echo $usage | awk '{print $3}')
  received_kb=$(echo $usage | awk '{print $4}')
  sent_kb=$(echo $usage | awk '{print $5}')
  total_kb=$(echo $usage | awk '{print $6}')

  if (( $(echo "$total_kb > $threshold_kb" | bc -l) )); then
    total_received_gb=$(echo "scale=3; $total_received_gb + $received_gb" | bc)
    total_sent_gb=$(echo "scale=3; $total_sent_gb + $sent_gb" | bc)
    total_usage_gb=$(echo "scale=3; $total_usage_gb + $total_gb" | bc)

    total_received_kb=$(echo "scale=3; $total_received_kb + $received_kb" | bc)
    total_sent_kb=$(echo "scale=3; $total_sent_kb + $sent_kb" | bc)
    total_usage_kb=$(echo "scale=3; $total_usage_kb + $total_kb" | bc)

    minute_count=$((minute_count + 1))

    daily_usage_percent=$(echo "scale=3; ($total_usage_gb / $daily_limit_gb) * 100" | bc)
    weekly_usage_percent=$(echo "scale=3; ($total_usage_gb / $weekly_limit_gb) * 100" | bc)
    monthly_usage_percent=$(echo "scale=3; ($total_usage_gb / $monthly_limit_gb) * 100" | bc)

    # Visualization using squares
    visualize() {
      local percent=$1
      local full_squares=$(echo "$percent / 10" | bc)
      local remainder=$(echo "$percent % 10" | bc)
      local visual=""
      for ((i=0; i<full_squares; i++)); do
        visual+="█"
      done
      if [ "$remainder" -ge 5 ]; then
        visual+="▌"
      fi
      echo "$visual"
    }

    daily_visual=$(visualize $daily_usage_percent)
    weekly_visual=$(visualize $weekly_usage_percent)
    monthly_visual=$(visualize $monthly_usage_percent)

    echo "Second $minute_count - Received: $received_gb GB / $received_kb KB, Sent: $sent_gb GB / $sent_kb KB, Total: $total_gb GB / $total_kb KB"
    echo "Cumulative Total - Received: $total_received_gb GB / $total_received_kb KB, Sent: $total_sent_gb GB / $total_sent_kb KB, Total: $total_usage_gb GB / $total_usage_kb KB"
    echo "Usage Percentages - Daily: $daily_usage_percent% $daily_visual, Weekly: $weekly_usage_percent% $weekly_visual, Monthly: $monthly_usage_percent% $monthly_visual"

    echo "$minute_count,$received_gb,$sent_gb,$total_gb,$received_kb,$sent_kb,$total_kb,$total_usage_gb,$weekly_usage_percent,$monthly_usage_percent,$daily_usage_percent,$weekly_usage_percent,$monthly_usage_percent" >> $usage_file
  fi
done

