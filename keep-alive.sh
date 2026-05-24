echo "Press [CTRL+C] to stop"
while :
do
	if [ "$2" -eq 1 ]; then
		echo "sending request..."
	fi
	if [ "$2" -ne 2 ]; then
		curl "$1" > /dev/null -s
	else
		curl "$1"
	fi
	sleep 30
done
keep-alive.sh
