
> module ScopeReader where

> import qualified Data.Map as M
> import Data.Maybe

> import Debug.Trace

> import DBAccess
> import Scope
> import TypeType


> readScope :: String -> IO Scope
> readScope dbName = withConn ("dbname=" ++ dbName) $ \conn -> do
>    typeInfo <- selectRelation conn
>                  "select t.oid as oid,\n\
>                  \       t.typtype,\n\
>                  \       t.typname,\n\
>                  \       t.typarray,\n\
>                  \       coalesce(e.typtype,'0') as atyptype,\n\
>                  \       e.oid as aoid,\n\
>                  \       e.typname as atypname\n\
>                  \  from pg_catalog.pg_type t\n\
>                  \  left outer join pg_type e\n\
>                  \    on t.typarray = e.oid\n\
>                  \  where pg_catalog.pg_type_is_visible(t.oid)\n\
>                  \   and not exists(select 1 from pg_catalog.pg_type el\n\
>                  \                       where el.typarray = t.oid)\n\
>                  \  order by t.typname;" []
>    let typeAssoc = concatMap convTypeInfoRow typeInfo
>        typeMap = M.fromList typeAssoc
>        types = map snd typeAssoc
>    castInfo <- selectRelation conn
>                  "select castsource,casttarget,castcontext from pg_cast;" []
>    let jlt k = {-trace ("stuff:" ++ show k ++"//") $-} fromJust $ M.lookup k typeMap
>    let casts = flip map castInfo
>                  (\l -> (jlt (l!!0), jlt (l!!1),
>                          case (l!!2) of
>                                      "a" -> AssignmentCastContext
>                                      "i" -> ImplicitCastContext
>                                      "e" -> ExplicitCastContext
>                                      _ -> error $ "unknown cast context " ++ (l!!2)))
>    typeCatInfo <- selectRelation conn
>                        "select pg_type.oid, typcategory, typispreferred from pg_type\n\
>                        \where pg_catalog.pg_type_is_visible(pg_type.oid);" []
>    let typeCats = flip map typeCatInfo
>                     (\l -> (jlt (l!!0), l!!1, read (l!!2)::Bool))
>    operatorInfo <- selectRelation conn
>                        "select oprname,\n\
>                        \       oprleft,\n\
>                        \       oprright,\n\
>                        \       oprresult\n\
>                        \from pg_operator\n\
>                        \      where not (oprleft <> 0 and oprright <> 0\n\
>                        \         and oprname = '@') --hack for now\n\
>                        \      order by oprname;" []
>    let getOps a b c [] = (a,b,c)
>        getOps pref post bin (l:ls) =
>          let bit = (\a -> (l!!0, a, jlt(l!!3)))
>          in case () of
>                   _ | l!!1 == "0" -> getOps pref (bit [jlt (l!!2)]:post) bin ls
>                     | l!!2 == "0" -> getOps (bit [jlt (l!!1)]:pref) post bin ls
>                     | otherwise -> getOps pref post ((bit [jlt (l!!1), jlt (l!!2)]):bin) ls
>    let (prefixOps, postfixOps, binaryOps) = getOps [] [] [] operatorInfo
>    return $ Scope [] [] [] prefixOps postfixOps binaryOps M.empty
>    --return $ Scope types casts typeCats M.empty
>    where
>      convTypeInfoRow l =
>        let name = (l!!2)
>            ctor = case (l!!1) of
>                     "b" -> ScalarType
>                     "c" -> CompositeType
>                     "d" -> DomainType
>                     "e" -> EnumType
>                     "p" -> (\t -> Pseudo (case t of
>                                                  "any" -> Any
>                                                  "anyarray" -> AnyArray
>                                                  "anyelement" -> AnyElement
>                                                  "anyenum" -> AnyEnum
>                                                  "anynonarray" -> AnyNonArray
>                                                  "cstring" -> Cstring
>                                                  "internal" -> Internal
>                                                  "language_handler" -> LanguageHandler
>                                                  "opaque" -> Opaque
>                                                  "record" -> Record
>                                                  "trigger" -> Trigger
>                                                  "void" -> Void
>                                                  _ -> error $ "unknown pseudo " ++ t))
>                     _ -> error $ "unknown type type: " ++ (l !! 1)
>            scType = ((l!!0), ctor name)
>        in if (l!!4) /= "0"
>           then [((l!!5,ArrayType $ ctor name)), scType]
>           else [scType]