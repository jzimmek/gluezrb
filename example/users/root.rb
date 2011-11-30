user do

  bash "update apt-tree" do
    code "apt-get update && touch /tmp/.gluez_apt"
    not_if "-f /tmp/.gluez_apt"
  end
  
  package "build-essential"
  package "curl"
  package "zlib1g-dev"
  package "libssl-dev"
  package "libcurl4-openssl-dev"
  package "libpq-dev"
  package "subversion"

end