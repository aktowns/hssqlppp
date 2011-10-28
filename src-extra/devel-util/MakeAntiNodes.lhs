The purpose of this code is to automatically generate a copy of the
ast data structures from AstInternal.ag, and produce a new set of data
types with some support for anti quotation nodes stuck in.

Then, generate a transform which takes the new nodes and converts them
to the original nodes, returning an error if an antinodes are in the
tree.

This code is seriously unreadable. Investigate using haskell-src-meta
or something similar to parse and obtain template haskell ast, which
can then use th, quasiquotation to make the pattern matching and code
generation much clearer. If can get this working, use same approach
for preprocessors examples for typesafe database access.

The code is quite fragile and depends on the exact style (or lack of)
of coding used in AstInternal.ag.

Run this from ghci:

change to the folder with the cabal file in
run ghci
enter:
:set -isrc-extra/util:src-extra/devel-util
:l "src-extra/devel-util/MakeAntiNodes.lhs"
writeAntiNodes

> module MakeAntiNodes (writeAntiNodes) where
>
> import Language.Haskell.Exts hiding (String)
> import qualified Language.Haskell.Exts as Exts
> import Data.Data
> import Data.Generics.Uniplate.Data
> import Data.Char
> import Data.Maybe
> import Control.Monad
> import Data.List

> --import Database.HsSqlPpp.Utils.Here
> import Text.Groom

> writeAntiNodes :: IO()
> writeAntiNodes = makeAntiNodes >>= writeFile "src/Database/HsSqlPpp/Internals/AstAnti.hs"

>
> preamble :: String
> preamble =
>   "{-\n\
>   \This file is autogenerated, to generate: load this file (MakeAntiNodes.lhs)\n\
>   \into ghci and run:\n\
>   \n\
>   \writeAntiNodes\n\
>   \n\\n\
>   \The path might need tweaking.\n\
>   \n\
>   \-}\n"
>
> nodesToAntificate :: [String]
> nodesToAntificate = ["ScalarExpr", "TriggerEvent", "Statement"]
>
> makeAntiNodes :: IO String
> makeAntiNodes = do
>   ast' <- pf "src/Database/HsSqlPpp/Internals/AstInternal.hs"
>   let ast = stripTyParen ast'
>   -- ast1 <- pf "Database/HsSqlPpp/Internals/AstAnti.hs"
>   -- trace (ppExpr ast) $ return ()
>   --  get the interesting declarations out
>   let ndecls = [(n,d) | d@(DataDecl _ _ _ (Ident n) _ _ _) <- universeBi ast
>                ,not $ isGeneratedName n
>                ,not $ isAuxiliary n]
>               ++ [(n,d) | d@(TypeDecl _ (Ident n) _ _) <- universeBi ast
>                  ,not $ isGeneratedName n
>                  ,not $ isAuxiliary n]
>   -- mapM_ putStrLn $ map fst ndecls
>   let decls = map snd ndecls
>   --  create the conversion functions
>   let convs = concatMap (makeConvertor $ map fst ndecls) decls
>   --  add the anti parts and return
>   return $ preamble ++
>            prettyPrint
>             (makeModule (exports ast)
>                        (publicConversions
>                         ++ addAntis decls
>                         ++ addAntis convs))
>   where
>     --  todo: match the exact uuagc generated names here
>     isGeneratedName n = '_' `elem` n || n `elem` ["Root", "ScalarExprRoot", "ParamName"]
>     --  auxiliary types used in type checking but not part of public ast
>     isAuxiliary n = n `elem` ["IDEnv"]
>     stripTyParen = transformBi $ \x -> case x of
>                      TyParen y -> y
>                      x1 -> x1
>
> pf :: String -> IO Module
> pf f = do
>   x <- parseFileWithMode pm f
>   case x of
>         ParseOk ast -> return ast
>         e -> error $ show e
>   where
>     pm = defaultParseMode {
>            parseFilename = f
>          ,extensions = [PatternGuards,ScopedTypeVariables,TupleSections]}

node conversions
-- -- -- -- -- -- -- --

pass in the list of type names from astinternal so we know which types
use a conversion function and which don't when recursing the
conversions

> makeConvertor :: [String] -> Decl -> [Decl]
> makeConvertor ts d =
>   [makeConvTypeSig n, fromJust makeConv]
>   where
>     makeConv = msum [
>                 convertPair ts d
>                ,convertMaybe d
>                ,convertList ts d
>                ,convertSum ts d
>                ,error "makeConvertor - no convertor found"] -- Just $ makeUndefined n]
>     n = getDeclName d
>
> makeConvTypeSig :: String -> Decl
> makeConvTypeSig s =
>   TypeSig nsrc
>           [Ident $ lowerFirst s]
>           (TyFun (TyCon (UnQual (Ident s)))
>            (TyCon (Qual (ModuleName "A") (Ident s))))
>
>
> {-makeUndefined :: String -> Decl
> makeUndefined s =
>   PatBind nsrc
>           (PVar (Ident $ lowerFirst s))
>           Nothing
>           (UnGuardedRhs (Var (UnQual (Ident "undefined"))))
>           (BDecls [])-}
>
> convertPair :: [String] -> Decl -> Maybe Decl
> convertPair ts (TypeDecl _ (Ident t) []
>              (TyTuple Boxed
>                  [TyCon (UnQual (Ident t1)),
>                   TyCon (UnQual (Ident t2))])) =
>             Just $ FunBind
>      [Match nsrc
>         (Ident $ lowerFirst t)
>         [PTuple [PVar (Ident "a"), PVar (Ident "b")]]
>         Nothing
>         (UnGuardedRhs
>            (Tuple
>               [convName ts t1 "a"
>               ,convName ts t2 "b"]))
>         (BDecls [])]
> convertPair _ _ = Nothing

TypeDecl (SrcLoc {srcFilename = "src/lib/Database/HsSqlPpp/Internals/AstInternal.hs", srcLine = 7201, srcColumn = 1}) (Ident "ScalarExprStatementListPair") [] (TyTuple Boxed [TyCon (UnQual (Ident "ScalarExpr")),TyCon (UnQual (Ident "StatementList"))])


TypeDecl a (Ident "StringTypeNameListPair") [
 (TyTuple Boxed
 [TyParen (TyCon (UnQual (Ident "String")))
          ,TyCon (UnQual (Ident "TypeNameList"))])

>
> convertMaybe :: Decl -> Maybe Decl
> convertMaybe (TypeDecl _ (Ident t) []
>                  (TyApp (TyCon (UnQual (Ident "Maybe")))
>                    (TyCon (UnQual (Ident t1))))) =
>              Just $ PatBind nsrc
>                       (PVar (Ident $ lowerFirst t))
>                       Nothing
>                       (UnGuardedRhs
>                        (App (Var (UnQual (Ident "fmap")))
>                                 (Var (UnQual (Ident $ lowerFirst t1)))))
>                       (BDecls [])
> convertMaybe _ = Nothing
>
> convertList :: [String] -> Decl -> Maybe Decl
> convertList ts (TypeDecl _ (Ident t) []
>              (TyList (TyCon (UnQual (Ident t1)))))
>              | t1 `elem` ts =
>                  Just $ PatBind nsrc
>                           (PVar (Ident $ lowerFirst t))
>                           Nothing
>                           (UnGuardedRhs
>                            (App (Var (UnQual (Ident "fmap")))
>                                     (Var (UnQual (Ident $ lowerFirst t1)))))
>                           (BDecls [])
>              | otherwise =
>                 Just $ PatBind nsrc
>                          (PVar (Ident $ lowerFirst t))
>                          Nothing
>                          (UnGuardedRhs (Var (UnQual (Ident "id"))))
>                          (BDecls [])
> convertList _ _ = Nothing
>
>
> convertSum :: [String] -> Decl -> Maybe Decl
> convertSum ts d =
>   let is = getCtors d
>       f = getDeclName d
>   in Just $ FunBind
>      [Match nsrc
>         (Ident $ lowerFirst f)
>         [PVar (Ident "x")]
>         Nothing
>         (UnGuardedRhs
>            (Case (Var (UnQual (Ident "x")))
>               (map (uncurry mkAlt) is)))
>         (BDecls [])]
>   where
>     mkAlt c cis = let anames = map (("a"++) . show . snd) $ zip cis [(1::Int)..]
>                       ant = zip anames cis
>                   in Alt nsrc
>                   (PApp (UnQual (Ident c))
>                      (map (PVar . Ident) anames))
>                   (mkCtor c ant)
>                   (BDecls [])
>     mkCtor c ant =
>         let elems = flip map ant $ \(a,t) -> convName ts t a
>         in UnGuardedAlt $ foldl App (Con (Qual (ModuleName "A") (Ident c))) elems
>

utils for conv generators
-------------------------

get the constructor information for a type, in a nice simple format

> getCtors :: Decl -> [(String,[String])]
> getCtors t =
>   case t of
>        DataDecl _ _ _ _ _ ctors _ -> map ctorInfo ctors
>        _ -> []
>   where
>     ctorInfo (QualConDecl _ _ _ (ConDecl (Ident n) as)) = (n, map aInfo as)
>     ctorInfo a = error $ "ctorInfo " ++ show a
>     aInfo (UnBangedTy (TyCon (UnQual (Ident m)))) = m
>     -- bit dodgy, if we find a maybe or list, we slap this on the end of the type
>     -- name and hope everything works out.
>     -- which it does, since the types in astinternal follow this convention
>     -- and the convname fn helps out as well
>     -- (I can't really believe it)
>     aInfo (UnBangedTy (TyList (TyCon (UnQual (Ident m))))) = m ++ "List"
>     aInfo (UnBangedTy (TyApp (TyCon (UnQual (Ident "Maybe"))) (TyCon (UnQual (Ident m)))))
>           = "Maybe" ++ m
>     aInfo (UnBangedTy (TyApp (TyCon (UnQual (Ident "Maybe"))) (TyList (TyCon (UnQual (Ident "String")))))) = "MaybeStringList"
>     aInfo (UnBangedTy (TyApp (TyCon (UnQual (Ident "Maybe"))) (TyList (TyCon (UnQual (Ident "NameComponent")))))) = "MaybeNameComponentList"

>     aInfo a = error $ "aInfo " ++ show a
>

get the conversion for a data type if it is defined in astinternal,
apply the conversion function otherwise just use the value unchanged

> convName :: [String] -> String -> String -> Exp
> convName ts tn l =
>   case () of
>     _ | tn `elem` ts -> App (Var (UnQual (Ident $ lowerFirst tn)))
>                         (Var (UnQual (Ident l)))
>       | unlist -> let tx = upperFirst unlistl
>                   in if tx `elem` ts
>                      then App (App (Var (UnQual (Ident "fmap")))
>                                        (Var (UnQual (Ident unlistl))))
>                               (Var (UnQual (Ident l)))
>                      else Var (UnQual (Ident l))
>       | unmaybe -> let tx = upperFirst unmaybel
>                    in if tx `elem` ts
>                       then App (App (Var (UnQual (Ident "fmap")))
>                                         (Var (UnQual (Ident $ lowerFirst tx))))
>                                (Var (UnQual (Ident l)))
>                       else Var (UnQual (Ident l))
>       | otherwise -> Var (UnQual (Ident l))
>   where
>     unlistl = lowerFirst $ take (length tn - 4) tn
>     unlist = "List" `isSuffixOf` tn
>     unmaybe = "Maybe" `isPrefixOf` tn
>     unmaybel = lowerFirst $ drop 5 tn


extract the name of the type being defined from a decl

> getDeclName :: Decl -> String
> getDeclName d =
>   case d of
>      DataDecl _ _ _ (Ident n) _ _ _ -> n
>      TypeDecl _ (Ident n) _ _ -> n
>      x -> error $ "getDeclName: " ++ groom x

add antis
---------

this is where we run over the tree and add the antictors and error
messages in the conversion functions

> addAntis :: [Decl] -> [Decl]
> addAntis = map antiize
>   where
>     antiTargFns = map lowerFirst nodesToAntificate
>     antiize d@(FunBind
>               [Match _ (Ident n) _ _ _ _]) |
>                 n `elem` antiTargFns =
>                     addAntiError d
>     antiize d@(DataDecl _ _ _ (Ident n) _ _ _) |
>                 n `elem` nodesToAntificate =
>                     addAntiCtor d
>     antiize x = x
>
> addAntiCtor :: Decl -> Decl
> addAntiCtor (DataDecl sl dn ct nm@(Ident n) tyv qcd d) =
>   DataDecl sl dn ct nm tyv (qcd ++ [antiCtor]) d
>   where
>     antiCtor =
>       QualConDecl nsrc [] []
>         (ConDecl (Ident $ "Anti" ++ n)
>            [UnBangedTy (TyCon (UnQual (Ident "String")))])
>
> addAntiCtor e = error $ "addAntiCtor " ++ show e
>
> addAntiError :: Decl -> Decl
> addAntiError (FunBind
>               [Match sl nm@(Ident n) pt ty
>                (UnGuardedRhs
>                 (Case (Var (UnQual (Ident "x"))) alts))
>                   bnd]) =
>   FunBind
>    [Match sl nm pt ty
>     (UnGuardedRhs
>      (Case (Var (UnQual (Ident "x"))) (alts ++ [antiAlt])))
>     bnd]
>   where
>     antiAlt :: Alt
>     antiAlt = Alt nsrc
>                  (PApp (UnQual (Ident $ "Anti" ++ upperFirst n)) [PWildCard])
>                  (UnGuardedAlt
>                     (App (Var (UnQual (Ident "error")))
>                        (Lit (Exts.String $ "can't convert anti " ++ n))))
>                  (BDecls [])
> addAntiError e = error $ "addAntiError " ++ show e

boilerplate
-----------

nice function names to be exported to do anti->vanilla ast conversions

> publicConversions :: [Decl]
> publicConversions =
>   [TypeSig
>      nsrc
>      [Ident "convertStatements"]
>      (TyFun (TyList (TyCon (UnQual (Ident "Statement"))))
>         (TyList (TyCon (Qual (ModuleName "A") (Ident "Statement"))))),
>    PatBind
>      nsrc
>      (PVar (Ident "convertStatements"))
>      Nothing
>      (UnGuardedRhs (Var (UnQual (Ident "statementList"))))
>      (BDecls []),
>    TypeSig
>      nsrc
>      [Ident "convertScalarExpr"]
>      (TyFun (TyCon (UnQual (Ident "ScalarExpr")))
>         (TyCon (Qual (ModuleName "A") (Ident "ScalarExpr")))),
>    PatBind
>      nsrc
>      (PVar (Ident "convertScalarExpr"))
>      Nothing
>      (UnGuardedRhs (Var (UnQual (Ident "scalarExpr"))))
>      (BDecls [])]

get the exports from astinternal, and keep the ones for types, and add
the public conversion functions

> exports :: (Data a) => a -> [ExportSpec]
> exports ast = map (EVar . UnQual . Ident )
>                  ["convertStatements", "convertScalarExpr", "attributeDef", "queryExpr"] ++
>               [ex | ex@(EThingAll _) <- universeBi ast] ++
>               [ex | ex@(EAbs _) <- universeBi ast]

take all the pieces and make a complete module to be pretty printed
ready for compilation

> makeModule :: [ExportSpec] -> [Decl] -> Module
> makeModule es =
>     Module nsrc
>         (ModuleName "Database.HsSqlPpp.Internals.AstAnti")
>         [LanguagePragma nsrc
>          [Ident "DeriveDataTypeable"]]
>         Nothing (Just es)
>         [ImportDecl{importLoc = nsrc,
>                     importModule = ModuleName "Data.Data",
>                     importQualified = False,
>                     importSrc = False, importPkg = Nothing, importAs = Nothing,
>                     importSpecs = Nothing},
>          ImportDecl{importLoc = nsrc,
>                     importModule = ModuleName "Database.HsSqlPpp.Internals.AstAnnotation",
>                     importQualified = False, importSrc = False, importPkg = Nothing,
>                     importAs = Nothing, importSpecs = Nothing},
>          ImportDecl{importLoc =
>                     nsrc,
>                     importModule = ModuleName "Database.HsSqlPpp.Internals.AstInternal",
>                     importQualified = True, importSrc = False, importPkg = Nothing,
>                     importAs = Just (ModuleName "A"), importSpecs = Nothing}]

boring little functions
-----------------------

> nsrc :: SrcLoc
> nsrc = SrcLoc "" 0 0
>
> lowerFirst :: String -> String
> -- lowerFirst "" = ""
> lowerFirst s = toLower (head s):tail s
>
> upperFirst :: String -> String
> -- upperFirst "" = ""
> upperFirst s = toUpper (head s):tail s
