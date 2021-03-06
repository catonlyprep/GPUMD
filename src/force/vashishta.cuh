/*
    Copyright 2017 Zheyong Fan, Ville Vierimaa, Mikko Ervasti, and Ari Harju
    This file is part of GPUMD.
    GPUMD is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
    GPUMD is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.
    You should have received a copy of the GNU General Public License
    along with GPUMD.  If not, see <http://www.gnu.org/licenses/>.
*/

#pragma once
#include "potential.cuh"
#include "utilities/gpu_vector.cuh"
#include <stdio.h>

struct Vashishta_Para {
  double B[2], cos0[2], C, r0, rc;
  double v_rc[3], dv_rc[3];
  double H[3], qq[3], lambda_inv[3], D[3], xi_inv[3], W[3];
  int eta[3];
  double rmin;
  double scale;
  int N;
};

struct Vashishta_Data {
  GPU_Vector<double> f12x; // partial forces
  GPU_Vector<double> f12y;
  GPU_Vector<double> f12z;
  GPU_Vector<int> NN_short; // for three-body part
  GPU_Vector<int> NL_short; // for three-body part
};

class Vashishta : public Potential
{
public:
  Vashishta(FILE*, const Neighbor& neighbor);
  virtual ~Vashishta(void);
  virtual void compute(
    const int type_shift,
    const Box& box,
    const Neighbor& neighbor,
    const GPU_Vector<int>& type,
    const GPU_Vector<double>& position,
    GPU_Vector<double>& potential,
    GPU_Vector<double>& force,
    GPU_Vector<double>& virial);

protected:
  void initialize_para(FILE*);
  Vashishta_Para vashishta_para;
  Vashishta_Data vashishta_data;
};
