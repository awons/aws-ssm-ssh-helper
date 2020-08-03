build:
	docker build -t aws-ssm-ssh-helper .

install:
	cp -p host/ssh/* ~/.ssh/
