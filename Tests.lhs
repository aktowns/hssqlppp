#!/usr/bin/env runghc

select * from test;
select a,b from test;
insert
update
delete

> import Test.HUnit
> import Test.QuickCheck
> import Test.Framework
> import Test.Framework.Providers.HUnit
> import Data.Char

 > import Test.Framework.Providers.QuickCheck2

> import Control.Monad

> import Grammar
> import Parser
> import PrettyPrinter

> main :: IO ()
> main = do
>   defaultMain [
>         checkParse "select 1;" [(SelectE $ IntegerLiteral 1)]
>        ,checkParse "select 1+1;"
>           [(SelectE $ BinaryOperatorCall "+" (IntegerLiteral 1) (IntegerLiteral 1))]
>        ,checkParse "select 1 + 1;"
>           [(SelectE $ BinaryOperatorCall "+" (IntegerLiteral 1) (IntegerLiteral 1))]
>        ,checkParse "select 1+1+1;"
>           [(SelectE $ BinaryOperatorCall "+" (IntegerLiteral 1) (IntegerLiteral 1))]
>        ,checkParse "select 'test';" [(SelectE $ StringLiteral "test")]
>        ,checkParse "select fn();" [(SelectE $ FunctionCall "fn" [])]
>        ,checkParse "select fn(1);" [(SelectE $ FunctionCall "fn" [IntegerLiteral 1])]
>        ,checkParse "select fn (1);" [(SelectE $ FunctionCall "fn" [IntegerLiteral 1])]
>        ,checkParse "select fn( 1);" [(SelectE $ FunctionCall "fn" [IntegerLiteral 1])]
>        ,checkParse "select fn(1 );" [(SelectE $ FunctionCall "fn" [IntegerLiteral 1])]
>        ,checkParse "select fn(1) ;" [(SelectE $ FunctionCall "fn" [IntegerLiteral 1])]
>        ,checkParse "select fn('test');" [(SelectE $ FunctionCall "fn" [StringLiteral "test"])]
>        ,checkParse "select fn(1, 'test');"
>           [(SelectE $ FunctionCall "fn" [IntegerLiteral 1, StringLiteral "test"])]
>        ,checkParse "select 1;\nselect 2;" [(SelectE $ IntegerLiteral 1)
>                                           ,(SelectE $ IntegerLiteral 2)
>                                           ]
>        ,checkParse "create table test (\n\
>                    \  fielda text,\n\
>                    \  fieldb int\n\
>                    \);" [(CreateTable "test" [
>                                            AttributeDef "fielda" "text"
>                                           ,AttributeDef "fieldb" "int"
>                                           ])]
>        ,checkParse "select * from tbl;" [(Select Star "tbl")]
>        ,checkParse "select a,b from tbl;" [(Select (SelectList ["a","b"]) "tbl")]
>        -- ,testProperty "random  statement" prop_select_ppp
>        ]

> checkParse :: String -> [Statement] -> Test.Framework.Test
> checkParse src ast = testCase ("parse " ++ src) $ do
>   let ast' = case parseSql src of
>               Left er -> error $ show er
>               Right l -> l
>   assertEqual ("parse " ++ src) ast ast'

 > instance Arbitrary Char where
 >     arbitrary     = choose ('\32', '\128')
 >     coarbitrary c = variant (ord c `rem` 4)

 > instance Arbitrary Identifier where
 >     arbitrary = liftM Identifier $ listOf' $ choose ('\97', '\122')

> instance Arbitrary Statement where
>     arbitrary = oneof [
>                  liftM SelectE arbitrary
>                 ,liftM2 CreateTable aIdentifier arbitrary
>                 ]

> instance Arbitrary AttributeDef where
>     arbitrary = liftM2 AttributeDef aIdentifier aIdentifier

> instance Arbitrary Expression where
>     arbitrary = oneof [
>                  liftM Identifier aIdentifier
>                 ,liftM IntegerLiteral arbitrary
>                 ,liftM StringLiteral $ listOf1 $ arbitrary
>                 ,liftM2 FunctionCall aIdentifier arbitrary
>                 ,liftM3 BinaryOperatorCall aBinaryOp arbitrary arbitrary
>                 ]

> aString :: Gen [Char]
> aString = listOf1 $ choose ('\32', '\128')

> aIdentifier :: Gen [Char]
> aIdentifier = listOf1 $ choose ('\97', '\122')

> aBinaryOp :: Gen [Char]
> aBinaryOp = elements ["+", "-"]

> parseThrowError :: String -> [Statement]
> parseThrowError s = case parseSql s of
>               Left er -> error $ show er
>               Right l -> l

> prop_select_ppp :: [Statement] -> Bool
> prop_select_ppp s = (parseThrowError (printSql s)) == s

> listOf' :: Gen a -> Gen [a]
> listOf' gen = sized $ \n ->
>   do k <- choose (1,n)
>      vectorOf' k gen

> vectorOf' :: Int -> Gen a -> Gen [a]
> vectorOf' k gen = sequence [ gen | _ <- [0..k] ]
