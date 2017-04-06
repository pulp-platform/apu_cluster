-------------------------------------------------------------------------------
-- Copyright (C) 2017 ETH Zurich, University of Bologna
-- All rights reserved.
--
-- This code is under development and not yet released to the public.
-- Until it is released, the code is under the copyright of ETH Zurich and
-- the University of Bologna, and may contain confidential and/or unpublished 
-- work. Any reuse/redistribution is strictly forbidden without written
-- permission from ETH Zurich.
--
-- Bug fixes and contributions will eventually be released under the
-- SolderPad open hardware license in the context of the PULP platform
-- (http://www.pulp-platform.org), under the copyright of ETH Zurich and the
-- University of Bologna.
-------------------------------------------------------------------------------
-- Engineer:       Michael Schaffner - schaffner@iis.ee.ethz.ch       
--                                                                    
--                                                                    
-- Design Name:    firstone_arbiter.vhd                      
-- Project Name:                                                      
-- Language:       VHDL
--                                                                    
-- Description:
--
-- determines the index of the first LSB which is nonzero in the vector Vector_DI.
-- if needed, the vector can be flipped such that the index of the first nonzero
-- MSB is calculated. this entity uses a tree structure to provide an acceptable
-- combinatorial delay when large vectors are used. if there are no ones in the
-- vector, the index is invalid and the signal NoOnes_SO will be asserted...
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
-- use work.VHDLTools.all;
use IEEE.math_real.all;


entity firstone_arbiter is
  generic(
    G_VECTORLEN  : natural := 13;
    G_FLIPVECTOR : boolean := false
    );
  port (
    Vector_DI      : in  std_logic_vector(G_VECTORLEN-1 downto 0);
    FirstOneIdx_DO : out unsigned(integer(ceil(log2(real(G_VECTORLEN))))-1 downto 0);
    NoOnes_SO      : out std_logic
    );
end firstone_arbiter;

architecture RTL of firstone_arbiter is

  constant C_NUM_LEVELS : natural := integer(ceil(log2(real(G_VECTORLEN+1))));

  type   IndexLut_T is array (natural range <>) of unsigned(integer(ceil(log2(real(G_VECTORLEN))))-1 downto 0);
  signal IndexLut_D : IndexLut_T(0 to G_VECTORLEN-1);

  signal SelNodes_D   : std_logic_vector(0 to 2**C_NUM_LEVELS-2);
  signal IndexNodes_D : IndexLut_T(0 to 2**C_NUM_LEVELS-2);

  signal TmpVector_D : std_logic_vector(Vector_DI'range);

begin

-----------------------------------------------------------------------------
--  flip vector if needed
-----------------------------------------------------------------------------

  --noflip_g : if not G_FLIPVECTOR generate
    TmpVector_D <= Vector_DI;
  --end generate noflip_g;

  -- flip_g : if G_FLIPVECTOR generate
  --   TmpVector_D <= VectorFliplr(Vector_DI);
  -- end generate flip_g;

-----------------------------------------------------------------------------
--  generate tree structure
-----------------------------------------------------------------------------

  index_lut_g : for k in 0 to G_VECTORLEN-1 generate
    IndexLut_D(k) <= to_unsigned(k, IndexLut_D(k)'length);
  end generate index_lut_g;

  levels_g : for level in 0 to C_NUM_LEVELS-1 generate
    --------------------------------------------------------------
    lower_levels_g : if level < C_NUM_LEVELS-1 generate
      nodes_on_level_g : for k in 0 to 2**level-1 generate
        SelNodes_D(2**level-1+k)   <= SelNodes_D(2**(level+1)-1+k*2) or SelNodes_D(2**(level+1)-1+k*2+1);
        IndexNodes_D(2**level-1+k) <= IndexNodes_D(2**(level+1)-1+k*2) when (SelNodes_D(2**(level+1)-1+k*2) = '1')
                                      else IndexNodes_D(2**(level+1)-1+k*2+1);
      end generate nodes_on_level_g;
    end generate lower_levels_g;
    --------------------------------------------------------------
    highest_level_g : if level = C_NUM_LEVELS-1 generate
      nodes_on_level_g : for k in 0 to 2**level-1 generate
        -- if two successive indices are still in the vector...
        both_valid_g : if k*2 < G_VECTORLEN-1 generate
          SelNodes_D(2**level-1+k)   <= TmpVector_D(k*2) or TmpVector_D(k*2+1);
          IndexNodes_D(2**level-1+k) <= IndexLut_D(k*2) when (TmpVector_D(k*2) = '1')
                                        else IndexLut_D(k*2+1);
        end generate both_valid_g;
        -- if only the first index is still in the vector...
        one_valid_g : if k*2 = G_VECTORLEN-1 generate
          SelNodes_D(2**level-1+k)   <= TmpVector_D(k*2);
          IndexNodes_D(2**level-1+k) <= IndexLut_D(k*2);
        end generate one_valid_g;
        -- if index is out of range
        none_valid_g : if k*2 > G_VECTORLEN-1 generate
          SelNodes_D(2**level-1+k)   <= '0';
          IndexNodes_D(2**level-1+k) <= (others => '0');
        end generate none_valid_g;
      end generate nodes_on_level_g;
    end generate highest_level_g;
    --------------------------------------------------------------
  end generate levels_g;

-----------------------------------------------------------------------------
--  connect output
-----------------------------------------------------------------------------

  FirstOneIdx_DO <= IndexNodes_D(0);
  NoOnes_SO      <= not SelNodes_D(0);

end RTL;

