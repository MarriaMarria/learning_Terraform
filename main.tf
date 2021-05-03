# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 2.26"
    }
  }

  required_version = ">= 0.14.9"
}

provider "azurerm" {
  features {}
}
# creating admin user for VM
# variable "admin_username" {
#   type        = string
#   description = "Administrator user name for VM"
# }

# creating admin password for VM
# variable "admin_password" {
#   type        = string
#   description = "password"
# }


# creating resource group
resource "azurerm_resource_group" "rg" {
  name     = "mariaTFResourceGroup"
  location = "eastus2"

  # This configuration provisions an azurerm_resource_group resource named rg. The resource name is used to reference the Terraform resource created in the resource block throughout the configuration. It is not the same as the name of the resource group in Azure.

  tags = {
    Environmant = "Terraform Getting Started"
    Team        = "Devops"
  }
}

# creating virtual network

resource "azurerm_virtual_network" "vnet" {
  name                = "mariaTFnet"
  address_space       = ["10.0.0.0/16"] # list => accepts more than one value
  location            = "eastus2"
  resource_group_name = azurerm_resource_group.rg.name

  #To create a new Azure VNet, you have to specify the name of the resource group to contain the vnet. The value of the resource_group_name attribute is an expression using Terraform interpolation. This  expression azurerm_resource_group.rg.name creates the implicit dependency on the azurerm_resource_group object named rg.
}

# creating subnet

resource "azurerm_subnet" "subnet" {
  name                 = "mariaTFSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# creating public IP

resource "azurerm_public_ip" "publicip" {
  name     = "mariaTFPublicIP"
  location = "eastus2"
  # or location = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
}

# creating Network Security Group and rule
# Network security groups enable inbound or outbound traffic to be enabled or denied.
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group

resource "azurerm_network_security_group" "nsg" {
  name                = "mariaTFNSG"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

}

# Creating network interface
# A network interface enables an Azure Virtual Machine to communicate with internet, Azure, and on-premises resources. 
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface

resource "azurerm_network_interface" "nic" {
  name                = "mariaNIC"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "mariaNICConfg"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = azurerm_public_ip.publicip.id
  }
}

# Create a Linux virtual machine
resource "azurerm_linux_virtual_machine" "vm" {
  name                  = "mariaTFVM"
  resource_group_name   = azurerm_resource_group.rg.name
  location              = "eastus2"
  size                  = "Standard_B1ls"
  admin_username        = "maria"
  network_interface_ids = [azurerm_network_interface.nic.id]

  admin_ssh_key {
    username   = "maria"
    public_key = file("./key_vm.pub.pub")
  }

  os_disk {
    name                 = "mariaOsDisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  # os_profile {
  #   computer_name = "mariaTFVM"
  #   # admin_username = var.admin_username

  #   # admin_password = var.admin_password
  # }



}


data "azurerm_public_ip" "ip" {
  name                = azurerm_public_ip.publicip.name
  resource_group_name = azurerm_linux_virtual_machine.vm.resource_group_name # the last .resourse_group_name is the value we actually want to grab here
  depends_on          = [azurerm_linux_virtual_machine.vm]
}
