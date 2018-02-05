NAME = zoo

SRC = zoo.rb

E_PWD = ${PWD}

install:
	@(echo "install")
	@gem install bundle 1> /dev/null
	@bundle install 1> /dev/null
	@ln -sf $(SRC) $(NAME)
	@chmod 755 $(NAME)
	@(echo "add '\033[32mexport PM_PATH=$(E_PWD)\033[00m' in your zshrc or bash_profile")
	@(echo "add '\033[32mexport PATH=$(E_PWD):\$$PATH\033[00m' in your zshrc or bash_profile")
	@(echo "and \033[32msource\033[00m him")

