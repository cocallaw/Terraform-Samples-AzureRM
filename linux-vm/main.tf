# Configure the Microsoft Azure Provider
provider "azurerm" {
}

# Create a resource group if it doesn’t exist
resource "azurerm_resource_group" "terraformlabrg01" {
    name     = "Terraform-Lab"
    location = "eastus"

    tags {
        Project = "Terraform Lab"
    }
}

# Create virtual network
resource "azurerm_virtual_network" "terraformlabvnet01" {
    name                = "tf-lab-vnet"
    address_space       = ["10.0.0.0/16"]
    location            = "eastus"
    resource_group_name = "${azurerm_resource_group.terraformlabrg01.name}"

    tags {
        Project = "Terraform Lab"
    }
}

# Create subnet
resource "azurerm_subnet" "terraformlabvnetsub01" {
    name                 = "tfsubnet01"
    resource_group_name  = "${azurerm_resource_group.terraformlabrg01.name}"
    virtual_network_name = "${azurerm_virtual_network.terraformlabvnet01.name}"
    address_prefix       = "10.0.1.0/24"
}

# Create public IPs
resource "azurerm_public_ip" "terraformlabpip01" {
    name                         = "terraformpip01"
    location                     = "eastus"
    resource_group_name          = "${azurerm_resource_group.terraformlabrg01.name}"
    public_ip_address_allocation = "dynamic"

    tags {
        Project = "Terraform Lab"
    }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "terraformlabnsg01" {
    name                = "tfnsg01"
    location            = "eastus"
    resource_group_name = "${azurerm_resource_group.terraformlabrg01.name}"

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

    tags {
        Project = "Terraform Lab"
    }
}

# Create network interface
resource "azurerm_network_interface" "myterraformnic" {
    name                      = "myNIC"
    location                  = "eastus"
    resource_group_name       = "${azurerm_resource_group.terraformlabrg01.name}"
    network_security_group_id = "${azurerm_network_security_group.terraformlabnsg01.id}"

    ip_configuration {
        name                          = "myNicConfiguration"
        subnet_id                     = "${azurerm_subnet.terraformlabvnetsub01.id}"
        private_ip_address_allocation = "dynamic"
        public_ip_address_id          = "${azurerm_public_ip.terraformlabpip01.id}"
    }

    tags {
        Project = "Terraform Lab"
    }
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = "${azurerm_resource_group.terraformlabrg01.name}"
    }

    byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "mystorageaccount" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = "${azurerm_resource_group.terraformlabrg01.name}"
    location                    = "eastus"
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags {
        Project = "Terraform Lab"
    }
}

# Create virtual machine
resource "azurerm_virtual_machine" "myterraformvm" {
    name                  = "myVM"
    location              = "eastus"
    resource_group_name   = "${azurerm_resource_group.terraformlabrg01.name}"
    network_interface_ids = ["${azurerm_network_interface.myterraformnic.id}"]
    vm_size               = "Standard_DS1_v2"

    storage_os_disk {
        name              = "myOsDisk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
    }

    storage_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "16.04.0-LTS"
        version   = "latest"
    }

    os_profile {
        computer_name  = "myvm"
        admin_username = "azureuser"
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
            path     = "/home/azureuser/.ssh/authorized_keys"
            key_data = "ssh-rsa AAAA.....something.......uw=="
        }
    }

    boot_diagnostics {
        enabled = "true"
        storage_uri = "${azurerm_storage_account.mystorageaccount.primary_blob_endpoint}"
    }

    tags {
        Project = "Terraform Lab"
    }
}