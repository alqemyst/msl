import Foundation
import Virtualization
import ArgumentParser

let trap: sig_t = { signal in
  //print("Got signal: \(signal). Use poweroff command inside VM.")
}

struct MSL: ParsableCommand {
  @Option(help: "Number of CPUs VM will use")
  var cpu: UInt8 = 1

  @Option(help: "RAM size in MB")
  var ram: UInt64 = 1024

  @Option(help: "Kernel image path")
  var kernel: String = "vmlinuz"

  @Option(help: "Ramdisk image path")
  var ramdisk: String = "initrd"

  @Option(help: "Root image path")
  var disk: String?

  @Option(help: "Kernel's command-line parameters")
  var cmd: String = "console=hvc0 rd.break=initqueue"

  @Option(help: "Network device MAC address")
  var mac: String?

  @Flag(help: "Create storage as NVME storage device")
  var nvme = false

  func run() throws {
    signal(SIGINT, trap)

    let kernelURL = URL(fileURLWithPath: kernel, isDirectory: false)
    let ramdiskURL = URL(fileURLWithPath: ramdisk, isDirectory: false)

    let configuration = VZVirtualMachineConfiguration()
    configuration.cpuCount = Int(cpu)
    configuration.memorySize = ram * 1048576
    configuration.entropyDevices = [VZVirtioEntropyDeviceConfiguration()]
    configuration.serialPorts = [ createConsoleConfiguration() ]
    configuration.bootLoader = createBootLoader(kernelURL: kernelURL, ramdiskURL: ramdiskURL, cmd: cmd)

    if (disk != nil) {
      configuration.storageDevices = [ try createStorageDeviceConfiguration(disk: disk, nvme: nvme) ]
    }

    configuration.networkDevices = [ createNetworkDeviceConfiguration(mac: mac) ]

    do {
      try configuration.validate()
    } catch {
      MSL.exit(withError: error)
    }

    let virtualMachine = VZVirtualMachine(configuration: configuration)

    let delegate = Delegate()
    virtualMachine.delegate = delegate

    virtualMachine.start { (result) in
      if case let .failure(error) = result {
        MSL.exit(withError: error)
      }
    }

    RunLoop.main.run(until: Date.distantFuture)
  }
}

MSL.main()
