provider "azurerm" {
  features {}
}

variable "resource_group_location" {
  default     = "eastus"
  description = "Location of the resource group."
}

variable "prefix" {
  type        = string
  default     = "iis"
  description = "Prefix of the resource name"
}

resource "azurerm_resource_group" "rg" {
  location = var.resource_group_location
  name     = "rg-${var.prefix}"
}

# Create virtual network
resource "azurerm_virtual_network" "network" {
  name                = "vnet-${var.prefix}"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Create subnet
resource "azurerm_subnet" "subnet" {
  name                 = "subnet-${var.prefix}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.network.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create public IPs
resource "azurerm_public_ip" "public_ip" {
  name                = "pip-${var.prefix}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

# Create network interface
resource "azurerm_network_interface" "nic" {
  name                = "nic-${var.prefix}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "my_nic_configuration"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }
}

# Create virtual machine
resource "azurerm_windows_virtual_machine" "main" {
  name                  = "vm-${var.prefix}"
  admin_username        = "azureuser"
  admin_password        = "@Zurepassw0rd"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.nic.id]
  size                  = "Standard_DS1_v2"

  os_disk {
    name                 = "myOsDisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }
}

# Configure IIS and create a simple html page
resource "azurerm_virtual_machine_extension" "install-iis" {
  name                 = "${var.prefix}-wsi"
  virtual_machine_id   = azurerm_windows_virtual_machine.main.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.9"

  settings = <<SETTINGS
    {
      "commandToExecute": "powershell -encodedCommand ${textencodebase64(file("${path.module}/configure-iis.ps1"), "UTF-16LE")}"
    }
  SETTINGS
}

resource "azurerm_dev_test_global_vm_shutdown_schedule" "example" {
  virtual_machine_id = azurerm_windows_virtual_machine.main.id
  location           = azurerm_resource_group.rg.location
  enabled            = true

  daily_recurrence_time = "2100"
  timezone              = "W. Europe Standard Time"

  notification_settings {
    enabled = false
  }
}

output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "public_ip_address" {
  value = azurerm_windows_virtual_machine.main.public_ip_address
}

output "admin_password" {
  sensitive = true
  value     = azurerm_windows_virtual_machine.main.admin_password
}
