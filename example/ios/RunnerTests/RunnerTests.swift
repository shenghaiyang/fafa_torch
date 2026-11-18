import Testing

@testable import fafa_torch

struct RunnerTests {

  @Test func defaultStateBeforeRegister() throws {
    let plugin = FafaTorchPlugin()

    #expect(try plugin.isOn() == false)
  }

}
