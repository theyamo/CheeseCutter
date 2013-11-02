//  ---------------------------------------------------------------------------
//  This file is part of reSID, a MOS6581 SID emulator engine.
//  Copyright (C) 2004  Dag Lem <resid@nimrod.no>
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 2 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
//  ---------------------------------------------------------------------------
//  Filter distortion code written by Antti S. Lankila 2007 - 2009.

#include "filterfp.h"
#include "sidfp.h"

// ----------------------------------------------------------------------------
// Constructor.
// ----------------------------------------------------------------------------
FilterFP::FilterFP()
{
  model = (chip_model) 0; // neither 6581/8580; init time only
  enable_filter(true);
  /* approximate; sid.cc calls us when set_sampling_parameters() occurs. */
  set_clock_frequency(1e6f);
  /* these parameters are a work-in-progress. */
  set_distortion_properties(0.5f, 3.3e6f, 3.0e-4f);
  /* sound similar to alankila6581r4ar3789 */
  set_type3_properties(1299501.5675945764f, 284015710.29875594f, 1.0065089724604026f, 18741.324073610594f);
  /* sound similar to trurl8580r5_3691 */
  set_type4_properties(6.55f, 20.f);
  reset();
  set_chip_model(MOS6581);
}


// ----------------------------------------------------------------------------
// Enable filter.
// ----------------------------------------------------------------------------
void FilterFP::enable_filter(bool enable)
{
  enabled = enable;
  if (! enabled)
    filt = 0; // XXX should also restore this...
}

// ----------------------------------------------------------------------------
// Set chip model.
// ----------------------------------------------------------------------------
void FilterFP::set_chip_model(chip_model model)
{
    this->model = model;
    set_Q();
    set_w0();
}

void FilterFP::set_nonlinearity(float nl)
{
    nonlinearity = nl;
    set_w0();
}

/* dist_CT eliminates 1/x at hot spot */
void FilterFP::set_clock_frequency(float clock) {
    clock_frequency = clock;
    distortion_CT = 1.f / (sidcaps_6581 * clock_frequency);
    set_w0();
}

void FilterFP::set_distortion_properties(float a, float nl, float il)
{
    attenuation = a;
    distortion_nonlinearity = nl;
    intermixing_leaks = il;
    set_w0();
}

void FilterFP::set_type4_properties(float k, float b)
{
    type4_k = k;
    type4_b = b;
    set_w0();
}

void FilterFP::set_type3_properties(float br, float o, float s, float mfr)
{
    type3_baseresistance = br;
    type3_offset = o;
    type3_steepness = -logf(s) / FC_TO_OSC; /* s^x to e^(x*ln(s)), 1/e^x == e^-x. */
    type3_minimumfetresistance = mfr;
    set_w0();
}

// ----------------------------------------------------------------------------
// SID reset.
// ----------------------------------------------------------------------------
void FilterFP::reset()
{
  fc = 0;
  res = filt = voice3off = hp_bp_lp = 0; 
  vol = 0;
  volf = Vhp = Vbp = Vlp = 0;
  type3_fc_kink_exp = 0;
  type4_w0_cache = 0;
  set_w0();
  set_Q();
}

// ----------------------------------------------------------------------------
// Register functions.
// ----------------------------------------------------------------------------
void FilterFP::writeFC_LO(reg8 fc_lo)
{
  fc = (fc & 0x7f8) | (fc_lo & 0x007);
  set_w0();
}

void FilterFP::writeFC_HI(reg8 fc_hi)
{
  fc = ((fc_hi << 3) & 0x7f8) | (fc & 0x007);
  set_w0();
}

void FilterFP::writeRES_FILT(reg8 res_filt)
{
  res = (res_filt >> 4) & 0x0f;
  set_Q();
  filt = enabled ? res_filt & 0x0f : 0;
}

void FilterFP::writeMODE_VOL(reg8 mode_vol)
{
  voice3off = mode_vol & 0x80;

  hp_bp_lp = mode_vol >> 4;

  vol = mode_vol & 0x0f;
  volf = static_cast<float>(vol) / 15.f;
}

// Set filter cutoff frequency.
void FilterFP::set_w0()
{
  if (model == MOS6581) {
    float type3_fc_kink = SIDFP::kinked_dac(fc, nonlinearity, 11);
    type3_fc_kink_exp = type3_offset * expf(type3_fc_kink * type3_steepness * FC_TO_OSC);
  }
  if (model == MOS8580) {
    type4_w0_cache = type4_w0();
  }
}

// Set filter resonance.
void FilterFP::set_Q()
{
  if (model == MOS6581) {
    _1_div_Q = 1.f / (0.5f + res / 20.f);
  } else {
    _1_div_Q = 1.f / (0.707f + res / 15.f);
  }
}
