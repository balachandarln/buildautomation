variable "prefix" {
  default = "kyndryl-boi"
}

resource "azurerm_resource_group" "example" {
  name     = "${var.prefix}-resources-balachandar2-rg"
  location = "South India"
}

resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
}

resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_network_interface" "main" {
  name                = "${var.prefix}-nic"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  ip_configuration {
    name                          = "testconfiguration1"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.main.id
  }
}

resource "azurerm_public_ip" "main" {
  name                = "${var.prefix}-public-ip"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  allocation_method   = "Static"
  sku                 = "Standard"
}
resource "azurerm_linux_virtual_machine" "main" {
  name                            = "${var.prefix}-vm-balachandar2"
  location                        = azurerm_resource_group.example.location
  resource_group_name             = azurerm_resource_group.example.name
  size                            = "Standard_B1s"
  admin_username                  = "ansibleuser"
  admin_password                  = "Docker@12345"
  disable_password_authentication = false
  network_interface_ids = [
    azurerm_network_interface.main.id
  ]
  admin_ssh_key {
    username   = "ansibleuser"
    public_key = file("/home/ansibleuser/.ssh/id_rsa.pub")
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "Canonical"
    sku       = "22_04-lts"
    offer     = "0001-com-ubuntu-server-jammy"
    version   = "latest"
  }
  custom_data = base64encode(<<EOF
          #cloud-config
  users:
    - name: ansibleuser
      groups: sudo
      shell: /bin/bash
      sudo: ALL=(ALL) NOPASSWD:ALL
      ssh-authorized-keys:
        - ${var.ansible_pub_key}
  runcmd:
   #!/bin/bash
  	- sudo apt-get update
  	- sudo apt-get install -y software-properties-common
  	- sudo add-apt-repository --yes --update ppa:ansible/ansible
  	- sudo apt-get install -y ansible
  	- sudo apt-get install -y ssh
  	- sudo systemctl restart ssh
  	- sudo systemctl enable ssh
        EOF
  )
}
