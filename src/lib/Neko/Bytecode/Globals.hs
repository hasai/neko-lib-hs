{-|
Module      : Neko.Bytecode.Globals
Description : Global values for a Neko module
Copyright   : (c) Petr Penzin, 2015
License     : BSD2
Maintainer  : penzin.dev@gmail.com
Stability   : experimental
Portability : cross-platform

Emit and parse global values for a Neko module.

-}
module Neko.Bytecode.Globals where

import Data.ByteString.Lazy as BS
import Data.ByteString.Lazy.Char8 as BSChar
import Data.Binary.Get
import Data.Either
import Data.Maybe
import Data.Word
import Data.Int

import Neko.IO

-- | Global value type
data Global =
        GlobalVar String -- ^ Global variable (name)
      | GlobalFunction (Int, Int) -- ^ Function
      | GlobalString String -- ^ String literal
      | GlobalFloat String -- ^ Floating point constant
      | GlobalDebug ([String], [(Int, Int)]) -- ^ Debug information
      | GlobalVersion Int -- ^ Version record
      deriving (Show, Eq)

-- | Read globals from a bytestring
readGlobals :: Word32 -- ^ Number of global values to read
            -> ByteString -- ^ Bytestring to read from
            -> Maybe ([Global], ByteString) -- ^ On success: list of global values read and unconsumed bytestring
readGlobals n bs = if (isRight res) then (Just (gs, rest)) else Nothing 
    where res = runGetOrFail (getGlobals n) bs
          Right (rest, _, gs) = res

-- | Read a single global value, if succesfull return a single global value and remaining bytestring
readGlobal :: ByteString -- ^ Bytes to read from
           -> Maybe (Global, ByteString) -- ^ Read value and the rest of bytes (if successfull)
readGlobal bs = if (isRight res) then (Just (g, rest)) else Nothing 
    where res = runGetOrFail getGlobal bs
          Right (rest, _, g) = res

-- | Get a list of globals from a bytestring
getGlobals :: Word32 -- ^ number of globals
           -> Get [Global] -- ^ decode a list
getGlobals 0 = return []
getGlobals n = getGlobal >>= \g -> getGlobals (n - 1) >>= \gs -> return (g:gs)

-- | Read a global from a bytestring
getGlobal :: Get Global
getGlobal = getWord8
        >>= \b -> if (b == 1) then getGlobalVar else
                  if (b == 2) then error "TODO getGlobal: implement GlobalFunction" else
                  if (b == 3) then getGlobalString else
                  if (b == 4) then error "TODO getGlobal: implement GlobalFloat" else
                  if (b == 5) then error "TODO getGlobal: implement GlobalDebug" else
                  if (b == 6) then error "TODO getGlobal: implement GlobalVersion" else
                  fail "getGlobal: urecognized global"

-- | Decode a global variable
getGlobalVar :: Get Global
getGlobalVar = getLazyByteStringNul >>= \b -> return ( GlobalVar $ BSChar.unpack b)

-- | Decode a global string
getGlobalString :: Get Global
getGlobalString = getWord16le
              >>= \length -> getLazyByteString (fromIntegral length)
              >>= \s -> return (GlobalString $ BSChar.unpack s)
