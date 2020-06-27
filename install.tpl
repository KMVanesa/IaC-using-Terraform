#! /bin/bash
sudo apt-get install libpq-dev python-dev -y
cd /home/ubuntu/
echo export access_key=${a_key} >> .bashrc
echo export secret_key=${s_key} >> .bashrc
echo export endpoint=${endpoint} >> .bashrc
echo export db_name=${db_name} >> .bashrc
echo export db_user=${db_user} >> .bashrc
echo export db_pass=${db_pass} >> .bashrc
echo export bucket=${bucket} >> .bashrc
touch run.sh
sudo chmod 775 run.sh 
echo unzip DjangoApp1 >> run.sh
echo cd DjangoApp1 >> run.sh
echo pip3 install -r requirements.txt >> run.sh
echo python3 manage.py migrate >> run.sh
echo python3 manage.py runserver 0.0.0.0:8080 >> run.sh