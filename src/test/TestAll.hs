import Test.Tasty
import Test.Tasty.SmallCheck as SC
import Neko
import Data.ByteString.Lazy

main = defaultMain tests

tests :: TestTree
tests = testGroup "Tests" [dasmTests, globalsReadTests]

dasmTests = testGroup "Disassemble tests"
  [ SC.testProperty "Disassemble hello world" $
      (readModule hello) == Right (N {globals=[GlobalString "Hello world!\n", GlobalVar "var"], code=[AccGlobal 0, Push, AccBuiltin "print", Call 1]})
  , SC.testProperty "Disassemble empty bytestring" $
      (readModule $ pack []) == Left "Failed to read magic value"
  , SC.testProperty "Invalid magic value" $
      (readModule $ pack [0x4f, 0x4b, 0x45, 0x4e, 0x02, 0x00, 0x00, 0x00]) == Left "Failed to read magic value"
  , SC.testProperty "Too short to get globals" $
      (readModule $ pack [0x4e, 0x45, 0x4b, 0x4f, 0x02, 0x00])
                                                                  == Left "Failed to read number of globals"
  , SC.testProperty "Too short to get fields" $
      (readModule $ pack [0x4e, 0x45, 0x4b, 0x4f, 0x02, 0x00, 0x00, 0x00,  0x01, 0x00])
                                                                  == Left "Failed to read number of fields"
  , SC.testProperty "Too short to get code size" $
      (readModule $ pack [0x4e, 0x45, 0x4b, 0x4f, 0x02, 0x00, 0x00, 0x00,  0x01, 0x00, 0x00, 0x00, 0x07, 0x00])
                                                                  == Left "Failed to read code size"
  , SC.testProperty "Invalid number of globals" $
      (readModule $ pack [0x4e, 0x45, 0x4b, 0x4f, 0xFF, 0xFF, 0xFF, 0xFF,  0x01, 0x00, 0x00, 0x00, 0x07, 0x00, 0x00, 0x00])
                                                                  == Left "Number of globals not between 0 and 0xFFFF"
  , SC.testProperty "Invalid number of fields" $
      (readModule $ pack [0x4e, 0x45, 0x4b, 0x4f, 0x02, 0x00, 0x00, 0x00,  0xFF, 0xFF, 0xFF, 0xFF, 0x07, 0x00, 0x00, 0x00])
                                                                  == Left "Number of fields not between 0 and 0xFFFF"
  , SC.testProperty "Invalid code size" $
      (readModule $ pack [0x4e, 0x45, 0x4b, 0x4f, 0x02, 0x00, 0x00, 0x00,  0x01, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFF])
                                                                  == Left "Code size not between 0 and 0xFFFFFF"
  ]

globalsReadTests = testGroup "Globals READ tests"
  [ SC.testProperty "Read string constant and debug info" $
      (readGlobals 2 $ pack [0x03, 0x0d, 0x00, 0x48, 0x65, 0x6c, 0x6c, 0x6f,  0x20, 0x77, 0x6f, 0x72, 0x6c, 0x64, 0x21, 0x0a, 0x05, 0x01, 0x2e, 0x2e, 0x2f, 0x68, 0x65, 0x6c,  0x6c, 0x6f, 0x2e, 0x6e, 0x65, 0x6b, 0x6f, 0x00, 0x07, 0x00, 0x00, 0x00, 0x0c, 0x1a])
                                                                  == Just ([GlobalString "Hello World", GlobalDebug (["hello.neko"], [(7, 21)])], empty)
  ]

hello = pack [
              0x4e, 0x45, 0x4b, 0x4f, 0x02, 0x00, 0x00, 0x00,  0x01, 0x00, 0x00, 0x00, 0x07, 0x00, 0x00, 0x00,
              0x03, 0x0d, 0x00, 0x48, 0x65, 0x6c, 0x6c, 0x6f,  0x20, 0x77, 0x6f, 0x72, 0x6c, 0x64, 0x21, 0x0a,
              0x05, 0x01, 0x2e, 0x2e, 0x2f, 0x68, 0x65, 0x6c,  0x6c, 0x6f, 0x2e, 0x6e, 0x65, 0x6b, 0x6f, 0x00,
              0x07, 0x00, 0x00, 0x00, 0x0c, 0x1a, 0x70, 0x72,  0x69, 0x6e, 0x74, 0x00, 0x31, 0x4c, 0x2f, 0x2d,
              0x58, 0x8b, 0xc8, 0xad
             ]

