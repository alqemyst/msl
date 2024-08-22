import Foundation
import Virtualization

class Delegate: NSObject {
}

extension Delegate: VZVirtualMachineDelegate {
  func guestDidStop(_ virtualMachine: VZVirtualMachine) {
    print("The guest shut down. Exiting.")
    exit(EXIT_SUCCESS)
  }
}

func createBootLoader(kernelURL: URL, ramdiskURL: URL, cmd: String) -> VZBootLoader {
  let bootLoader = VZLinuxBootLoader(kernelURL: kernelURL)
  bootLoader.initialRamdiskURL = ramdiskURL
  bootLoader.commandLine = cmd

  return bootLoader
}

func createConsoleConfiguration() -> VZSerialPortConfiguration {
  let consoleConfiguration = VZVirtioConsoleDeviceSerialPortConfiguration()

  let inputFileHandle = FileHandle.standardInput
  let outputFileHandle = FileHandle.standardOutput

  // Put stdin into raw mode, disabling local echo, input canonicalization,
  // and CR-NL mapping.
  var attributes = termios()
  tcgetattr(inputFileHandle.fileDescriptor, &attributes)
  attributes.c_iflag &= ~tcflag_t(ICRNL)
  attributes.c_lflag &= ~tcflag_t(ICANON | ECHO)
  tcsetattr(inputFileHandle.fileDescriptor, TCSANOW, &attributes)

  let stdioAttachment = VZFileHandleSerialPortAttachment(fileHandleForReading: inputFileHandle, fileHandleForWriting: outputFileHandle)

  consoleConfiguration.attachment = stdioAttachment

  return consoleConfiguration
}

func createStorageDeviceConfiguration(disk: String?, nvme: Bool) throws -> VZStorageDeviceConfiguration {
  let diskImageURL = URL(fileURLWithPath: disk!, isDirectory: false)
  let diskImageAttachment = try VZDiskImageStorageDeviceAttachment(url: diskImageURL, readOnly: false)

  if #available(macOS 14.0, *), nvme {
    return VZNVMExpressControllerDeviceConfiguration(attachment: diskImageAttachment)
  }

  return VZVirtioBlockDeviceConfiguration(attachment: diskImageAttachment)
}

func createNetworkDeviceConfiguration(mac: String?) -> VZNetworkDeviceConfiguration {
  let networkDevice = VZVirtioNetworkDeviceConfiguration()
  networkDevice.attachment = VZNATNetworkDeviceAttachment()

  if (mac != nil) {
    networkDevice.macAddress = VZMACAddress(string: mac!) ?? VZMACAddress.randomLocallyAdministered()
  }
  
  return networkDevice
}
