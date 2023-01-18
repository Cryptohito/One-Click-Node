Crontab_file="/usr/bin/crontab"
Green_font_prefix="\033[32m"
Red_font_prefix="\033[31m"
Green_background_prefix="\033[42;37m"
Red_background_prefix="\033[41;37m"
Font_color_suffix="\033[0m"
Info="[${Green_font_prefix}Message${Font_color_suffix}]"
Error="[${Red_font_prefix}Error${Font_color_suffix}]"
Tip="[${Green_font_prefix}Attention${Font_color_suffix}]"
check_root() {
    [[ $EUID != 0 ]] && echo -e "${Error} Please change to the ROOT account or use ${Green_background_prefix}sudo su${Font_color_suffix} command to obtain temporary ROOT privileges." && exit 1
}

install_evn(){
    check_root
    sudo apt install -y unzip logrotate git jq sed wget curl coreutils systemd
	echo "Remove the previously installed GO version.............."
	sudo rm -rf /usr/local/go
	sudo apt-get remove golang
	sudo apt-get remove golang-go
	sudo apt-get autoremove
    echo "Installing the GO environment.............."
    go_package_url="https://go.dev/dl/go1.18.linux-amd64.tar.gz"
    go_package_file_name=${go_package_url##*\/}
    wget -q $go_package_url
    sudo tar -C /usr/local -xzf $go_package_file_name
    echo "export PATH=\$PATH:/usr/local/go/bin" >>~/.profile
    echo "export PATH=\$PATH:\$(go env GOPATH)/bin" >>~/.profile
    source ~/.profile
    rm go1.18.linux-amd64.tar.gz
    go version
    echo "Environment installed"
}

install_lavad(){
    git clone https://github.com/K433QLtr6RA9ExEq/GHFkqmTzpdNLDd6T.git
    cd GHFkqmTzpdNLDd6T/testnet-1
    source setup_config/setup_config.sh
    echo "Lava config file path: $lava_config_folder"
    mkdir -p $lavad_home_folder
    mkdir -p $lava_config_folder
    cp default_lavad_config_files/* $lava_config_folder
    cp genesis_json/genesis.json $lava_config_folder/genesis.json
    lavad_binary_path="$HOME/go/bin/"
    mkdir -p $lavad_binary_path
    echo "Adding Lavad to environment variables.............."
    wget https://lava-binary-upgrades.s3.amazonaws.com/testnet/v0.4.3/lavad
    chmod +x lavad
    sudo cp ./lavad /usr/local/bin/lavad
    echo "[Unit]
    Description=Lava Node
    After=network-online.target
    [Service]
    User=$USER
    ExecStart=$(which lavad) start --home=$lavad_home_folder --p2p.seeds $seed_node
    Restart=always
    RestartSec=180
    LimitNOFILE=infinity
    LimitNPROC=infinity
    [Install]
    WantedBy=multi-user.target" >lavad.service
    sudo mv lavad.service /lib/systemd/system/lavad.service
    sudo systemctl daemon-reload
    sudo systemctl enable lavad.service
    sudo systemctl restart systemd-journald
    sudo systemctl start lavad
    echo "Updating block height..........."
    temp_folder=$(mktemp -d) && cd $temp_folder
    required_upgrade_name="v0.4.3" 
    upgrade_binary_url="https://lava-binary-upgrades.s3.amazonaws.com/testnet/$required_upgrade_name/lavad"
    source ~/.profile
    sudo systemctl stop lavad
    wget "$upgrade_binary_url" -q -O $temp_folder/lavad
    chmod +x $temp_folder/lavad
    sudo cp $temp_folder/lavad $(which lavad)
    sudo systemctl start lavad
    echo "Start successfully! "
}

run_lavad(){
    sudo systemctl start lavad
    sleep 5
    echo "Start successfully! "
}

stop_lavad(){
    sudo systemctl start stop
    sleep 10
    echo "Stop successfully! "
}

log_lavad(){
    echo "Querying, if you want to quit LOG query, please use CTRL+C "
    sudo journalctl -u lavad -f
}

status_lavad(){
    echo "Querying, if you want to quit LOG query, please use CTRL+C "
    sudo systemctl status lavad
}

sync_lavad(){
    echo "Querying the synchronization status, false means that the latest block has been synchronized. "
    lavad status | jq .SyncInfo.catching_up
}

create_lavad(){
    read -p "Enter the wallet name: " name
    lavad keys add ${name}
    lavad tendermint show-validator
    echo "Please save the above information, including the wallet mnemonic, which can be imported into the Keplr wallet"
}

list_lavad(){
    echo "Querying....."
    lavad keys list
}

export_lavad(){
    read -p "Please enter the name of the wallet you want to export: " name
    echo "Exporting, please enter the encryption key for the exported file...."
    lavad keys export ${name}
}

import_lavad(){
    read -p "Please enter the name of the wallet you want to import:" name
    read -p "Please enter the location of the wallet file you want to import (right-click the file in Finalshell to copy the path):" locate
    echo "Exporting, please enter the encryption key for the exported file...."
    lavad keys import ${name} ${locate}
}

validator_lavad(){
    echo "Please use this function after synchronizing the nodes. If the synchronization is complete, please use 7.Querying Lavad synchronization "
    echo "At the same time, please make sure that your address has enough test tokens, please go to the official Discord faucet. "
    echo "Lava Official：https://discord.gg/5VcqgwMmkA"
    echo "Faucet tutorial will be updated in the future, and now the official channel is temporarily closed. "
    read -p "Please enter your wallet name: " name
    lavad tx staking create-validator \
    --amount="50000ulava" \
    --pubkey=$(lavad tendermint show-validator --home "$HOME/.lava/") \
    --moniker="${name}" \
    --chain-id=lava-testnet-1 \
    --commission-rate="0.10" \
    --commission-max-rate="0.20" \
    --commission-max-change-rate="0.01" \
    --min-self-delegation="10000" \
    --gas="auto" \
    --gas-adjustment "1.5" \
    --gas-prices="0.05ulava" \
    --home="$HOME/.lava/" \
    --from=${name}
    echo "If code: 0 is returned, the validator’s pledge is successful; otherwise, it fails and ignores subsequent operations or errors, just press CTRL+C to exit"
    sleep 10
    block_time=60
    validator_pubkey=$(lavad tendermint show-validator | jq .key | tr -d '"')
    lavad q staking validators | grep $validator_pubkey
    echo "Return the result after waiting for 1 minute....."
    sleep $block_time
    lavad status | jq .ValidatorInfo.VotingPower | tr -d '"'
    echo "If the returned number is greater than 0, the node verifier verification is successful, otherwise it fails"
}

update_lavad(){
    echo "Please visit the page https://github.com/lavanet/lava/releases to check the latest version. "
    echo "For example, the latest version is V0.4.3, just enter V0.4.3 below. "
    read -p "Please enter the latest version (eg V0.4.3): " release
    echo "The latest version you entered is - $release "
    read -r -p "Please confirm that the latest version entered is correct, please enter Y if it is correct, otherwise it will exit [Y/n] " input
    case $input in
        [yY][eE][sS]|[yY])
            echo "continue to update"
            ;;

        *)
            echo "exit update..."
            exit 1
            ;;
    esac
    temp_folder=$(mktemp -d) && cd $temp_folder
    upgrade_binary_url="https://lava-binary-upgrades.s3.amazonaws.com/testnet/${release}/lavad"
    source ~/.profile
    sudo systemctl stop lavad
    wget "$upgrade_binary_url" -q -O $temp_folder/lavad
    chmod +x $temp_folder/lavad
    sudo cp $temp_folder/lavad $(which lavad) 
    sudo systemctl start lavad
    echo "Update completed!"
}




echo && echo -e " ${Red_font_prefix}Lava Network One-click node ${Font_color_suffix} by \033[1;35mcryptohito\033[0m
This script is free and open source, created by twitter user ${Green_font_prefix}@cryptohito${Font_color_suffix} 
twitter: ${Green_font_prefix}https://twitter.com/cryptohito${Font_color_suffix}
Welcome fork and don't be scam!
 ———————————————————————
  -----Pre-install Functions------
 ${Green_font_prefix} 1.Install the operating environment ${Font_color_suffix}
 ${Green_font_prefix} 2.Install and run Lavad ${Font_color_suffix}
  -----Node Functions------
 ${Green_font_prefix} 3.Run Lavad ${Font_color_suffix}
 ${Red_font_prefix} 4.Stop Lavad ${Font_color_suffix}
  -----Query Functions------
 ${Green_font_prefix} 5.Querying Lavad logs ${Font_color_suffix}
 ${Green_font_prefix} 6.Querying Lavad status ${Font_color_suffix}
 ${Green_font_prefix} 7.Querying Lavad synchronization ${Font_color_suffix}
  -----Wallet Functions------
 ${Green_font_prefix} 8.Create Wallet ${Font_color_suffix}
 ${Green_font_prefix} 9.List Wallet ${Font_color_suffix}
 ${Green_font_prefix} 10.Export Wallet ${Font_color_suffix}
 ${Green_font_prefix} 11.Import Wallet ${Font_color_suffix}
  -----Others------
 ${Green_font_prefix} 12.Validator Lavad ${Font_color_suffix}
 ${Green_font_prefix} 13.Update Lavad ${Font_color_suffix}

 ———————————————————————" && echo
read -e -p " Please input the number [1-13]:" num
case "$num" in
1)
    install_evn
    ;;
2)
    install_lavad
    ;;
3)
    run_lavad
    ;;
4)
    stop_lavad
    ;;
5)
    log_lavad
    ;;
6)
    status_lavad
    ;;
7)
    sync_lavad
    ;;
8)
    create_lavad
    ;;
9)
    list_lavad
    ;;
10)
    export_lavad
    ;;
11)
    import_lavad
    ;;
12)
    validator_lavad
    ;;
13)
    update_lavad
    ;;


*)
    echo
    echo -e " ${Error} Please enter the correct number"
    ;;
esac
