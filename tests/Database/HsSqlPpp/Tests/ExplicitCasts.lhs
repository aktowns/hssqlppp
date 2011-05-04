
Tests using the tpch queries. Just tests the result type at the
moment.

> {-# LANGUAGE QuasiQuotes #-}
> module Database.HsSqlPpp.Tests.ExplicitCasts
>     (explicitCastTests) where
>
> import Test.HUnit
> import Test.Framework
> import Test.Framework.Providers.HUnit
> --import Data.List
> import Control.Monad
>
> --import Database.HsSqlPpp.Utils.Here
> import Database.HsSqlPpp.Parser
> import Database.HsSqlPpp.TypeChecker
> import Database.HsSqlPpp.Annotation
> import Database.HsSqlPpp.Catalog
> import Database.HsSqlPpp.SqlTypes
> import Database.HsSqlPpp.Utils.PPExpr
> --import Database.HsSqlPpp.Tests.TestUtils
> import Database.HsSqlPpp.PrettyPrinter
> --import Database.HsSqlPpp.Tests.TpchData


> --import Data.Data
> --import Data.Generics.Uniplate.Data
> --import Database.HsSqlPpp.Ast

>
> data Item = Group String [Item]
>           | Query String String
>
> explicitCastTests :: Test.Framework.Test
> explicitCastTests = itemToTft explicitCastTestData
>
> explicitCastTestData :: Item
> explicitCastTestData =
>   Group "explicitcasts" [
>     Query "select a+b from t;" "select (a::float8) + (b::float8) from t;"
>    ,Query "select case true when true then 1::int else 1::float4 end;"
>           "select case true when true then (1::int)::float4 else 1::float4 end;"
>    ,Query "select case when true then 1::int else 1::float4 end;"
>           "select case when true then (1::int)::float4 else 1::float4 end;"
>    ,Query "select 3::int between 1::float8 and 4::numeric;"
>           "select (3::int)::float8 between 1::float8 and (4::numeric)::float8;"
>    ,Query "select a from t where c between 1.0 and 1.2"
>           "select a from t where c between 1.0::numeric and 1.2::numeric"
>   ]

> itemToTft :: Item -> Test.Framework.Test
> itemToTft (Group s is) = testGroup s $ map itemToTft is
> itemToTft (Query sql sql1) = testCase ("ec " ++ sql) $ do
>   let ast = {-resetAnnotations $-} addExplicitCasts $ ptc sql
>       ast1 = {-resetAnnotations $-} canonicalizeTypeNames $ ptc sql1
>   when (resetAnnotations ast /= resetAnnotations ast1)
>     $ putStrLn $ printQueryExpr ast
>        ++ "\n" ++ printQueryExpr ast1
>        ++ "\n\n" ++ ppExpr ast
>        ++ "\n\n" ++ ppExpr ast1
>        ++ "\n\n"
>   assertEqual "" (resetAnnotations ast) (resetAnnotations ast1)
>   where
>     ptc s = typeCheckQueryExpr cat
>             $  case parseQueryExpr "" s of
>                  Left e -> error $ show e
>                  Right l -> l

> cat :: Catalog
> cat = case updateCatalog defaultTemplate1Catalog testCatalog of
>         Left x -> error $ show x
>         Right e -> e



> testCatalog :: [CatalogUpdate]
> testCatalog = [CatCreateTable "t" [("a", typeFloat4)
>                                   ,("b", typeInt)
>                                   ,("c", typeNumeric)] []]
