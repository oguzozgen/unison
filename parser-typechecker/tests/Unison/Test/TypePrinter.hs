module Unison.Test.TypePrinter where

import EasyTest
import Unison.Type
import Unison.TypePrinter
import Unison.Symbol (Symbol)
import Unison.Builtin
import Unison.Parser (Ann(..))
import qualified Unison.Util.Pretty as PP
import qualified Unison.PrettyPrintEnv as PPE


-- Test the result of the pretty-printer.  Expect the pretty-printer to
-- produce output that differs cosmetically from the original code we parsed.
-- Check also that re-parsing the pretty-printed code gives us the same ABT.
-- (Skip that latter check if rtt is false.)
-- Note that this does not verify the position of the PrettyPrint Break elements.
tc_diff_rtt :: Bool -> String -> String -> Int -> Test ()
tc_diff_rtt rtt s expected width =
   let input_type = Unison.Builtin.t s :: Unison.Type.AnnotatedType Symbol Ann
       get_names = PPE.fromNames Unison.Builtin.names
       prettied = pretty0 get_names (-1) input_type
       actual = if width == 0
                then PP.renderUnbroken $ prettied
                else PP.render width $ prettied
       actual_reparsed = Unison.Builtin.t actual
   in scope s $ tests [(
       if actual == expected then ok
       else do note $ "expected: " ++ show expected
               note $ "actual  : "   ++ show actual
               note $ "expectedS:\n"   ++ expected
               note $ "actualS:\n"   ++ actual
               note $ "show(input)  : "   ++ show input_type
               note $ "prettyprint  : "   ++ show prettied
               crash "actual != expected"
       ), (
       if (not rtt) || (input_type == actual_reparsed) then ok
       else do note $ "round trip test..."
               note $ "single parse: " ++ show input_type
               note $ "double parse: " ++ show actual_reparsed
               note $ "prettyprint  : "   ++ show prettied
               crash "single parse != double parse"
       )]

-- As above, but do the round-trip test unconditionally.
tc_diff :: String -> String -> Test ()
tc_diff s expected = tc_diff_rtt True s expected 0

-- As above, but expect not even cosmetic differences between the input string
-- and the pretty-printed version.
tc :: String -> Test ()
tc s = tc_diff s s

-- Use renderBroken to render the output to some maximum width.
tc_breaks :: String -> Int -> String -> Test ()
tc_breaks s width expected = tc_diff_rtt True s expected width

test :: Test ()
test = scope "typeprinter" . tests $
  [ tc "a -> b"
  , tc "()"
  , tc "Pair"
  , tc "Pair a b"
  , tc "Pair a a"
  , tc_diff "((a))" $ "a"
  , tc "Pair a ()" -- unary tuple
  , tc "(a, a)"
  , tc "(a, a, a)"
  , tc "(a, b, c, d)"
  , tc "Pair a (Pair a a)"
  , tc "Pair (Pair a a) a"
  , tc "{} (Pair a a)"
  , tc "a ->{} b"
  , tc "a ->{e1} b"
  , tc "a ->{e1, e2} b -> c ->{} d"
  , tc "a ->{e1, e2} b ->{} c -> d"
  , tc "a -> b -> c ->{} d"
  , tc "a -> b ->{} c -> d"
  , tc "{e1, e2} (Pair a a)"
  , tc "Pair (a -> b) (c -> d)"
  , tc "Pair a b ->{e1, e2} Pair a b ->{} Pair (a -> b) d -> Pair c d"
  , tc "[Pair a a]"
  , tc "'a"
  , tc "'Pair a a"
  , tc "a -> 'b"
  , tc "'(a -> b)"
  , tc "(a -> b) -> c"
  , tc "'a -> b"
  , tc "a -> 'b -> c"
  , tc "a -> (b -> c) -> d"
  , tc "(a -> b) -> c -> d"
  , tc "((a -> b) -> c) -> d"
  , tc "(∀ a. 'a) -> ()"
  , tc "(∀ a. (∀ b. 'b) -> a) -> ()"
  , tc_diff "∀ a. 'a" $ "'a"
  , tc "a -> '(b -> c)"
  , tc "a -> b -> c -> d"
  , tc "a -> 'Pair b c"
  , tc "a -> b -> 'c"
  , tc "a ->{e} 'b"
  , tc "a -> '{e} b"
  , tc "a -> '{e} b -> c"
  , tc "a -> '{e} b ->{f} c"
  , tc "a -> '{e} (b -> c)"
  , tc "a -> '{e} (b ->{f} c)"
  , tc "a -> 'b"
  , tc "a -> '('b)"
  , tc "a -> '('(b -> c))"
  , tc "a -> '('('(b -> c)))"
  , tc "a -> '{e} ('('(b -> c)))"
  , tc "a -> '('{e} ('(b -> c)))"
  , tc "a -> '('('{e} (b -> c)))"
  , tc "a -> 'b ->{f} c"
  , tc "a -> '(b -> c)"
  , tc "a -> '(b ->{f} c)"
  , tc "a -> '{e} ('b)"
  , pending $ tc "a -> '{e} 'b"      -- issue #249
  , pending $ tc "a -> '{e} '{f} b"  -- issue #249
  , tc "a -> '{e} ('b)"
  , tc_diff "a -> () ->{e} () -> b -> c" $ "a -> '{e} ('(b -> c))"
  , tc "a -> '{e} ('(b -> c))"
  , tc_diff "a ->{e} () ->{f} b" $ "a ->{e} '{f} b"
  , tc "a ->{e} '{f} b"
  , tc_diff "a -> () ->{e} () ->{f} b" $ "a -> '{e} ('{f} b)"
  , tc "a -> '{e} ('{f} b)"
  , tc "a -> '{e} () ->{f} b"
  , tc "a -> '{e} ('{f} (b -> c))"
  , tc "a ->{e} '(b -> c)"
  , tc "a -> '{e} (b -> c)"
  , tc_diff "a -> () ->{e} () -> b" $ "a -> '{e} ('b)"
  , tc "'{e} a"
  , tc "'{e} (a -> b)"
  , tc "'{e} (a ->{f} b)"
  , pending $ tc "Pair a '{e} b"                           -- parser hits unexpected '
  , tc_diff_rtt False "Pair a ('{e} b)" "Pair a '{e} b" 80 -- no RTT due to the above
  , tc "'(a -> 'a)"
  , tc "'()"
  , tc "'('a)"
  , pending $ tc "''a"  -- issue #249
  , pending $ tc "'''a" -- issue #249
  , tc_diff "∀ a . a" $ "a"
  , tc_diff "∀ a. a" $ "a"
  , tc_diff "∀ a . 'a" $ "'a"
  , pending $ tc_diff "∀a . a" $ "a" -- lexer doesn't accept, treats ∀a as one lexeme - feels like it should work
  , pending $ tc_diff "∀ A . 'A" $ "'A"  -- 'unknown parse error' - should this be accepted?

  , tc_diff_rtt False "a -> b -> c -> d"   -- hitting 'unexpected Semi' in the reparse
              "a\n\
              \-> b\n\
              \-> c\n\
              \-> d" 10

  , tc_diff_rtt False "a -> Pair b c -> d"   -- ditto, and extra line breaks that seem superfluous in Pair
              "a\n\
              \-> Pair b c\n\
              \-> d" 14

  , tc_diff_rtt False "Pair (forall a. (a -> a -> a)) b"    -- as above, and TODO not nesting under Pair
              "Pair\n\
              \  (∀ a. a -> a -> a) b" 24

  , tc_diff_rtt False "Pair (forall a. (a -> a -> a)) b"    -- as above, and TODO not breaking under forall
              "Pair\n\
              \  (∀ a. a -> a -> a)\n\
              \  b" 21

  ]
