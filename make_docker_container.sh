#!/bin/bash
branch=$1
log=/tmp/make_docker_container_$branch.log
numbers='^[0-9]+$'

#emojis
waiting=$'\U000231B'
ohno=$'\U0001F631'
question=$'\U0001F914'
uhoo=$'\U0001F64C'
typing=$'\U0002328'
angry=$'\U0001F92C'
longlife=$'\U0001F596'
info=$'\U0001F6A7'

function checa_porta() {
	numbers='^[0-9]+$'

	if ! [[ $1 =~ $numbers ]]
	then
		echo 1
	else
		is_used=`netstat -nap | grep "LISTEN" | grep -v unix | grep ":5$1" | wc -l`

                if [[ $is_used -gt 0 ]]
                then
                        echo 1
                else
                        echo ''
                fi
	fi
}

function checa_docker() {
	existe=`docker ps --filter "name=$1" | grep -v NAMES | wc -l`

	if [[ $existe -gt 0 ]]
	then
		echo 1
	else
		echo ''
	fi
}

function checa_branch() {
	existe=`docker exec --workdir /var/www/html $1 git ls-remote --heads origin $1 | wc -l`

	if [[ $existe -gt 0 ]]
	then
		echo ''
	else
		echo 1
	fi
}

if [ -n "${1// }" ]
then
	porta=${branch:${#branch}-4:4}
	err=$(checa_porta $porta)
	# CRIANDO TESTE DA PORTA
	while [[ -n $err ]]
	do
		echo ""
		read -r -p "$angry A porta ("$porta") não parece estar correta ou está em uso. Digite uma porta ou 'x' para sair: " porta

		if [[ $porta == "x" ]]
		then
			echo ""
		       	echo "$longlife Tchau!!"	
			exit 0
		fi
		
		echo ""
		err=$(checa_porta $porta)
	done

	#if [ -n "${2// }" ]
	#then	
		err2=$(checa_docker $branch)

		while [[ -n $err2 ]]
		do
			echo ""
			read -r -p "$angry O container ("$branch") já existe. Digite um novo nome ou 'x' para sair: " branch

			if [[ $branch == "x" ]]
			then
				echo ""
				echo "$longlife Tchau!!"
				exit 0
			fi

			err2=$(checa_docker $branch)
		done	

		echo ""
		echo "$waiting Criando container $branch."

		docker run -d -p 5$porta:80 -p 4$porta:8080 -v /home/agronet/upload_files:/var/www/html/application/upload_files -v /home/agronet/barcode:/var/www/html/agronet/resources/imagens/barcode -v /home/agronet/laudos:/var/www/html/agronet/laudos --name $branch agronet:2.0 > $log

		if [ "$?" == 0 ]
			echo ""
			echo "$uhoo Container $branch criado."

			echo ""
			echo "$waiting Verificando se o $branch existe."

			erro3=$(checa_branch $branch)

			while [[ -n $erro3 ]]
			do
				old_branch=$branch

				echo ""
				read -r -p "$angry O branch ("$branch") informado não existe. Digite o branch correto ou 'x' para sair: " branch

				if [[ $branch == "x" ]]
				then
					echo ""
					echo "$longlife Tchau!!"
					exit 0
				fi

				docker container rename $old_branch $branch

				erro3=$(checa_branch $branch)
				
			done

			docker exec --workdir /var/www/html $branch git fetch >> $log 
			docker exec --workdir /var/www/html $branch git checkout $branch >> $log 
			docker exec --workdir /var/www/html $branch git pull >> $log 

			echo ""
			read -r -p "$waiting Executar migrations? (y/n): " response

			while [[ $response != "y" && $response != "n" ]]
			do
				echo ""
				read -r -p "$question Executar migrations? (y/n): " response
			done	

			if [ $response == "y" ]
			then	
				echo ""
				read -r -p "$typing Digite o nome da base (padrão:\"agro_dev\"): " base
				if [ -z $base ]
				then
					base=agro_dev
				fi
				
				echo ""	
				echo "$waiting Migrating $base"
				docker exec --workdir /var/www/html $branch sed -i "s:agro_dev:$base:" application/config/application.ini phinx/phinx.php >> $log 
				docker exec --workdir /var/www/html $branch phinx/vendor/bin/phinx migrate --configuration phinx/phinx.php >> $log 
			fi
		then
			echo ""
			echo "$uhoo Ambiente de testes criado em http://teste2.agrobrasilseguros.com.br:5$porta"
			echo "$uhoo Ambiente de testes da API do Tablet criado em http://teste2.agrobrasilseguros.com.br:4$porta"
			echo "$uhoo Arquivo $log criado."
		else
			echo ""
			echo "$ohno Ooops! Algo errado ocorreu, verifica arquivo $log."
		fi
	#else
		# echo "$ohno Ooops! Usar: make_docker_container $porta <nome_branch>"
	#fi
else
	echo ""
	echo "$angry Usar: make_docker_container <nome_branch>"
fi
