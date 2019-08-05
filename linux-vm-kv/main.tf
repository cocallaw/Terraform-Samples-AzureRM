# Configure the Microsoft Azure Provider
provider "azurerm" {
}

data "azurerm_key_vault_secret" "mySecretSSHKey" {
  name      = "tfkvsvrSSHKey"
  vault_uri = "https://yourKeyVault.vault.azure.net/"
}

# Create a resource group if it doesn’t exist
resource "azurerm_resource_group" "tfkvlabrg01" {
    name     = "tf-kv-lab"
    location = "eastus"
}

# Create virtual network
resource "azurerm_virtual_network" "tfkvlabvnet01" {
    name                = "tf-kv-lab-vnet"
    address_space       = ["10.0.0.0/16"]
    location            = "eastus"
    resource_group_name = "${azurerm_resource_group.tfkvlabrg01.name}"

}

# Create subnet
resource "azurerm_subnet" "tfkvlabvnetsub01" {
    name                 = "tfkvsubnet01"
    resource_group_name  = "${azurerm_resource_group.tfkvlabrg01.name}"
    virtual_network_name = "${azurerm_virtual_network.tfkvlabvnet01.name}"
    address_prefix       = "10.0.1.0/24"
}

# Create public IPs
resource "azurerm_public_ip" "tfkvlabpip01" {
    name                         = "tf-kv-lab-pip01"
    location                     = "eastus"
    resource_group_name          = "${azurerm_resource_group.tfkvlabrg01.name}"
    allocation_method            = "Dynamic"

}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "tfkvlabnsg01" {
    name                = "tf-kv-lab-nsg01"
    location            = "eastus"
    resource_group_name = "${azurerm_resource_group.tfkvlabrg01.name}"

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

# Create network interface
resource "azurerm_network_interface" "tfkvlabnic01" {
    name                      = "tf-kv-lab-nic01"
    location                  = "eastus"
    resource_group_name       = "${azurerm_resource_group.tfkvlabrg01.name}"
    network_security_group_id = "${azurerm_network_security_group.tfkvlabnsg01.id}"

    ip_configuration {
        name                          = "myNicConfiguration"
        subnet_id                     = "${azurerm_subnet.tfkvlabvnetsub01.id}"
        private_ip_address_allocation = "dynamic"
        public_ip_address_id          = "${azurerm_public_ip.tfkvlabpip01.id}"
    }

}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = "${azurerm_resource_group.tfkvlabrg01.name}"
    }

    byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "tfkvlabstgacct01" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = "${azurerm_resource_group.tfkvlabrg01.name}"
    location                    = "eastus"
    account_tier                = "Standard"
    account_replication_type    = "LRS"

}

# Create virtual machine
resource "azurerm_virtual_machine" "tfkvlabsvr01" {
    name                  = "tfkvsvr01"
    location              = "eastus"
    resource_group_name   = "${azurerm_resource_group.tfkvlabrg01.name}"
    network_interface_ids = ["${azurerm_network_interface.tfkvlabnic01.id}"]
    vm_size               = "Standard_DS1_v2"

    storage_os_disk {
        name              = "tfkvsvr01-osDisk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
    }

    storage_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04.0-LTS"
        version   = "latest"
    }

    os_profile {
        computer_name  = "tfkvsvr01"
        admin_username = "azureuser"
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
            path     = "/home/azureuser/.ssh/authorized_keys"
            key_data = "${data.azurerm_key_vault_secret.mySecretSSHKey.value}"
        }
    }

    boot_diagnostics {
        enabled = "true"
        storage_uri = "${azurerm_storage_account.tfkvlabstgacct01.primary_blob_endpoint}"
    }

}