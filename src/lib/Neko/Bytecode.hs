{-|
Module      : Neko.Bytecode
Description : Emit and parse Neko bytecode
Copyright   : (c) Petr Penzin, 2015
License     : BSD3
Maintainer  : penzin.dev@gmail.com
Stability   : experimental
Portability : cross-platform

Primitives to emit and parse Neko bytecode, including instruction definitions.

-}
module Neko.Bytecode where

import Data.ByteString.Lazy as BS
import Data.ByteString.Lazy.Char8 as BSChar
import Data.Maybe
import Data.Either
import Data.Word
import Data.Int

import Neko.IO
import Neko.Bytecode.Globals

-- | Various NekoVM instructions
data Instruction = 
        -- getters
        AccNull
      | AccTrue
      | AccFalse
      | AccThis
      | AccInt Int
      | AccStack Int
      | AccGlobal Int
      | AccEnv Int
      | AccField String
      | AccArray
      | AccIndex Int
      | AccBuiltin String
        -- setters
      | SetStack Int
      | SetGlobal Int
      | SetEnv Int
      | SetField String
      | SetArray
      | SetIndex Int
      | SetThis
        -- stack ops
      | Push
      | Pop Int
      | Call Int
      | ObjCall Int
      | Jump Int
      | JumpIf Int
      | JumpIfNot Int
      | Trap Int
      | EndTrap
      | Ret Int
      | MakeEnv Int
      | MakeArray Int
        -- value ops
      | Bool
      | IsNull
      | IsNotNull
      | Add
      | Sub
      | Mult
      | Div
      | Mod
      | Shl
      | Shr
      | UShr
      | Or
      | And
      | Xor
      | Eq
      | Neq
      | Gt
      | Gte
      | Lt
      | Lte
      | Not
        -- extra ops
      | TypeOf
      | Compare
      | Hash
      | New
      | JumpTable Int
      | Apply Int
      | AccStack0
      | AccStack1
      | AccIndex0
      | AccIndex1
      | PhysCompare
      | TailCall (Int, Int)
      | Loop
      deriving (Show, Eq)

-- | A Neko module. Consists of global entities and a list of instructions
data Module = N {globals::[Global], code::[Instruction]} deriving (Show, Eq)

-- | Parse module from ByteString.
--   Return module or return an error string
readModule :: ByteString -> Either String Module
readModule bs = if (isNothing afterMagic) then (Left "Failed to read magic value")
                else readModuleData $ fromJust afterMagic
    where afterMagic = stripMagic bs

-- | Parse module from ByteString after magic value is stripped
--   Return module or return an error string
readModuleData :: ByteString -> Either String Module
readModuleData bs = if (isNothing moduleFields) then (Left err) else Right N {globals=[], code=[]}
    where (rest, err, moduleFields) = readModuleFields bs

-- | Read module fields to determine code size, number of globals, and number of fields
readModuleFields :: ByteString -- ^ ByteString to read from
                 -> (ByteString, String, Maybe (Int32, Int32, Int32)) -- ^ Unconsumed bytestring, status message, and the triple: number of globals, number of fields and code size
readModuleFields bs = if (isNothing resNumGlobals) then (bs, errNumGlobals, Nothing) else
                      if (isNothing resNumFields) then (bs, errNumFields, Nothing) else
                      if (isNothing resCodeSize) then (bs, errCodeSize, Nothing) else
                      if (isJust checkError) then (bs, fromJust checkError, Nothing) else
                      (bsAfter, "Success", Just (numGlobals, numFields, codeSize))
                    where
                      resNumGlobals = readInt32 bs
                      (numGlobals, afterNumGlobals) = fromJust resNumGlobals
                      resNumFields = readInt32 afterNumGlobals
                      (numFields, afterNumFields) = fromJust resNumFields
                      resCodeSize = readInt32 afterNumFields
                      (codeSize, bsAfter) = fromJust resCodeSize
                      errNumGlobals = "Failed to read number of globals"
                      errNumFields = "Failed to read number of fields"
                      errCodeSize = "Failed to read code size"
                      checkError = checkModuleFields numGlobals numFields codeSize

-- | Check module fields,
--   return an error string if any of values is out of range, otherwise return Nothing.
checkModuleFields :: Int32 -- ^ Suggested number of globals
                  -> Int32 -- ^ Suggested number of fields
                  -> Int32 -- ^ Suggested code size (number of instructions)
                  -> Maybe String -- ^ Error message for out of range value, Nothing on success
checkModuleFields globals fields code
     = if (globals < 0 || globals > 0xFFFF) then Just "Number of globals not between 0 and 0xFFFF" else
       if (fields < 0 || fields > 0xFFFF) then Just "Number of fields not between 0 and 0xFFFF" else
       if (code < 0 || code > 0xFFFFFF) then Just "Code size not between 0 and 0xFFFFFF" else
       Nothing

-- | Check first four bytes for magic value. Return the rest of the string if OK, otherwise return Nothing
stripMagic :: ByteString -> Maybe ByteString
stripMagic bs = if (isPrefixOf (BSChar.pack "NEKO") bs) then (Just $ BS.drop 4 bs) else Nothing

