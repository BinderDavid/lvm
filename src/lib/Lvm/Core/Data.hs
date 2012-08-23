{------------------------------------------------------------------------
  The Core Assembler.

  Copyright 2001, Daan Leijen. All rights reserved. This file
  is distributed under the terms of the GHC license. For more
  information, see the file "license.txt", which is included in
  the distribution.
------------------------------------------------------------------------}

--  $Id$

module Lvm.Core.Data 
   ( CoreModule, CoreDecl
   , Expr(..), Note(..), Binds(..), Bind(..)
   , Alts, Alt(..), Pat(..), Literal(..), Con(..)
   ) where

import Lvm.Common.Byte   ( Bytes )
import Lvm.Common.Id     ( Id )
import Lvm.Core.Module
import Lvm.Common.IdSet  ( IdSet )
import Text.PrettyPrint.Leijen
import Lvm.Common.Byte         ( stringFromBytes )
import Lvm.Common.IdSet        ( listFromSet )
import Lvm.Core.PrettyId ( ppId, ppVarId, ppConId )

----------------------------------------------------------------
-- Modules
----------------------------------------------------------------
type CoreModule = Module Expr
type CoreDecl   = Decl Expr

----------------------------------------------------------------
-- Core expressions:
----------------------------------------------------------------
data Expr       = Let       !Binds Expr       
                | Match     !Id Alts
                | Ap        Expr Expr
                | Lam       !Id Expr
                | Con       !(Con Expr)
                | Var       !Id
                | Lit       !Literal 
                | Note      !Note !Expr

data Note       = FreeVar   !IdSet

data Binds      = Rec       ![Bind]
                | Strict    !Bind
                | NonRec    !Bind

data Bind       = Bind      !Id Expr

type Alts       = [Alt]
data Alt        = Alt       !Pat Expr

data Pat        = PatCon    !(Con Tag) ![Id]
                | PatLit    !Literal
                | PatDefault

data Literal    = LitInt    !Int
                | LitDouble !Double
                | LitBytes  !Bytes

data Con tag    = ConId  !Id
                | ConTag tag !Arity
                
----------------------------------------------------------------
-- Pretty printing
----------------------------------------------------------------

instance Pretty Expr where
   pretty = ppExpr 0

ppExpr :: Int -> Expr -> Doc
ppExpr p expr
  = case expr of
   --   (Let (Strict (Bind id1 expr)) (Match id2 alts)) | id1 == id2
   --               -> prec 0 $ hang 2 (text "case" <+> ppExpr 0 expr <+> text "of" <+> ppId id1 <$> ppAlts alts)
      Match x as  -> prec 0 $ align (text "match" <+> ppVarId x <+> text "with" <+> text "{" <$> pretty  as
                              <+> text "}")
      Let bs x    -> prec 0 $ align (ppLetBinds bs (text "in" <+> ppExpr 0 x))
      Lam x e     -> prec 0 $ text "\\" <> ppVarId x <+> ppLams "->" (</>)  e
      Ap e1 e2    -> prec 9 $ ppExpr  9 e1 <+> ppExpr  10 e2
      Var x       -> ppVarId  x
      Con con     -> pretty con
      Lit lit     -> pretty lit
      Note n e  -> 
         case n of
            FreeVar fv -> align (text "{" <+> sep (map (ppVarId ) (listFromSet fv)) <+> text "}"
                             <$> ppExpr p e)
  where
    prec p'  | p' >= p   = id
             | otherwise = parens

instance Pretty a => Pretty (Con a) where
   pretty con =
      case con of
         ConId x          -> ppConId x
         ConTag tag arity -> text "#(" <> pretty tag <> char ',' <> pretty arity <> text ")"
 
----------------------------------------------------------------
--
----------------------------------------------------------------

ppLams :: String -> (Doc -> Doc -> Doc) -> Expr -> Doc
ppLams arrow next expr
  = case expr of
      Lam x e -> ppVarId x <+> ppLams arrow next  e
      _       -> text arrow `next` ppExpr  0 expr

ppLetBinds :: Binds -> Doc -> Doc
ppLetBinds binds doc
  = case binds of
      NonRec bind -> nest 4 (text "let" <+> pretty bind) <$> doc
      Strict bind -> nest 5 (text "let!" <+> pretty bind) <$> doc
      Rec recs    -> nest 8 (text "let rec" <+> pretty recs) <$> doc

instance Pretty Bind where
   pretty (Bind x expr) =
      nest 2 (ppId  x <+> ppLams "=" (</>)  expr <> semi)
   prettyList = vcat . map pretty

instance Pretty Alt where
   pretty (Alt pat expr) =
      nest 4 (text "|" <+> pretty pat <+> text "->" </> ppExpr 0 expr)
   prettyList = vcat . map pretty

----------------------------------------------------------------
--
----------------------------------------------------------------

instance Pretty Pat where 
   pretty pat = 
      case pat of
         PatCon con ids -> hsep (pretty con : map (ppVarId) ids)
         PatLit lit  -> pretty lit
         PatDefault  -> text "_"

instance Pretty Literal where 
   pretty lit = 
      case lit of
         LitInt i    -> pretty i
         LitDouble d -> pretty d
         LitBytes s  -> text (show (stringFromBytes s))
