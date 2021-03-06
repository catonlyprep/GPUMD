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

/*----------------------------------------------------------------------------80
The class defining the simulation model.
------------------------------------------------------------------------------*/

#include "atom.cuh"
#include "box.cuh"
#include "group.cuh"
#include "neighbor.cuh"
#include "read_xyz.cuh"
#include "utilities/common.cuh"
#include "utilities/error.cuh"

void read_xyz_in_line_1(
  FILE* fid_xyz,
  int& N,
  int& MN,
  double& rc,
  int& triclinic,
  int& has_velocity_in_xyz,
  std::vector<Group>& group)
{
  int num_of_grouping_methods = 0;
  int count = fscanf(
    fid_xyz, "%d%d%lf%d%d%d\n", &N, &MN, &rc, &triclinic, &has_velocity_in_xyz,
    &num_of_grouping_methods);
  PRINT_SCANF_ERROR(count, 6, "Reading error for line 1 of xyz.in.");
  group.resize(num_of_grouping_methods);

  if (N < 2) {
    PRINT_INPUT_ERROR("Number of atoms should >= 2.");
  } else {
    printf("Number of atoms is %d.\n", N);
  }

  if (MN < 1) {
    PRINT_INPUT_ERROR("Maximum number of neighbors should >= 1.");
  } else if (MN > 1024) {
    PRINT_INPUT_ERROR("Maximum number of neighbors should <= 1024.");
  } else {
    printf("Maximum number of neighbors is %d.\n", MN);
  }

  if (rc <= 0) {
    PRINT_INPUT_ERROR("Initial cutoff for neighbor list should > 0.");
  } else {
    printf("Initial cutoff for neighbor list is %g A.\n", rc);
  }

  if (triclinic == 0) {
    printf("Use orthogonal box.\n");
  } else if (triclinic == 1) {
    printf("Use triclinic box.\n");
  } else {
    PRINT_INPUT_ERROR("Invalid box type.");
  }

  if (has_velocity_in_xyz == 0) {
    printf("Do not specify initial velocities here.\n");
  } else if (has_velocity_in_xyz == 1) {
    printf("Specify initial velocities here.\n");
  } else {
    PRINT_INPUT_ERROR("Invalid has_velocity flag.");
  }

  if (num_of_grouping_methods == 0) {
    printf("Have no grouping method.\n");
  } else if (num_of_grouping_methods > 0 && num_of_grouping_methods <= 10) {
    printf("Have %d grouping method(s).\n", num_of_grouping_methods);
  } else {
    PRINT_INPUT_ERROR("Number of grouping methods should be 1 to 10.");
  }
}

void read_xyz_in_line_2(FILE* fid_xyz, Box& box)
{
  if (box.triclinic == 1) {
    double ax, ay, az, bx, by, bz, cx, cy, cz;
    int count = fscanf(
      fid_xyz, "%d%d%d%lf%lf%lf%lf%lf%lf%lf%lf%lf", &box.pbc_x, &box.pbc_y, &box.pbc_z, &ax, &ay,
      &az, &bx, &by, &bz, &cx, &cy, &cz);
    PRINT_SCANF_ERROR(count, 12, "Reading error for line 2 of xyz.in.");

    box.cpu_h[0] = ax;
    box.cpu_h[3] = ay;
    box.cpu_h[6] = az;
    box.cpu_h[1] = bx;
    box.cpu_h[4] = by;
    box.cpu_h[7] = bz;
    box.cpu_h[2] = cx;
    box.cpu_h[5] = cy;
    box.cpu_h[8] = cz;
    box.get_inverse();

    printf("Box matrix h = [a, b, c] is\n");
    for (int d1 = 0; d1 < 3; ++d1) {
      for (int d2 = 0; d2 < 3; ++d2) {
        printf("%20.10e", box.cpu_h[d1 * 3 + d2]);
      }
      printf("\n");
    }

    printf("Inverse box matrix g = inv(h) is\n");
    for (int d1 = 0; d1 < 3; ++d1) {
      for (int d2 = 0; d2 < 3; ++d2) {
        printf("%20.10e", box.cpu_h[9 + d1 * 3 + d2]);
      }
      printf("\n");
    }
  } else {
    double lx, ly, lz;
    int count =
      fscanf(fid_xyz, "%d%d%d%lf%lf%lf", &box.pbc_x, &box.pbc_y, &box.pbc_z, &lx, &ly, &lz);
    PRINT_SCANF_ERROR(count, 6, "Reading error for line 2 of xyz.in.");

    if (lx < 0) {
      PRINT_INPUT_ERROR("Box length in x direction < 0.");
    }
    if (ly < 0) {
      PRINT_INPUT_ERROR("Box length in y direction < 0.");
    }
    if (lz < 0) {
      PRINT_INPUT_ERROR("Box length in z direction < 0.");
    }

    box.cpu_h[0] = lx;
    box.cpu_h[1] = ly;
    box.cpu_h[2] = lz;
    box.cpu_h[3] = lx * 0.5;
    box.cpu_h[4] = ly * 0.5;
    box.cpu_h[5] = lz * 0.5;

    printf("Box lengths are\n");
    printf("    Lx = %20.10e A\n", lx);
    printf("    Ly = %20.10e A\n", ly);
    printf("    Lz = %20.10e A\n", lz);
  }

  if (box.pbc_x == 1) {
    printf("Use periodic boundary conditions along x.\n");
  } else if (box.pbc_x == 0) {
    printf("Use     free boundary conditions along x.\n");
  } else {
    PRINT_INPUT_ERROR("Invalid boundary conditions along x.");
  }

  if (box.pbc_y == 1) {
    printf("Use periodic boundary conditions along y.\n");
  } else if (box.pbc_y == 0) {
    printf("Use     free boundary conditions along y.\n");
  } else {
    PRINT_INPUT_ERROR("Invalid boundary conditions along y.");
  }

  if (box.pbc_z == 1) {
    printf("Use periodic boundary conditions along z.\n");
  } else if (box.pbc_z == 0) {
    printf("Use     free boundary conditions along z.\n");
  } else {
    PRINT_INPUT_ERROR("Invalid boundary conditions along z.");
  }
}

void read_xyz_in_line_3(
  FILE* fid_xyz,
  const int N,
  const int has_velocity_in_xyz,
  int& number_of_types,
  std::vector<int>& cpu_type,
  std::vector<double>& cpu_mass,
  std::vector<double>& cpu_position_per_atom,
  std::vector<double>& cpu_velocity_per_atom,
  std::vector<Group>& group)
{
  cpu_type.resize(N);
  cpu_mass.resize(N);
  cpu_position_per_atom.resize(N * 3);
  cpu_velocity_per_atom.resize(N * 3);
  number_of_types = -1;

  for (int m = 0; m < group.size(); ++m) {
    group[m].cpu_label.resize(N);
    group[m].number = -1;
  }

  for (int n = 0; n < N; n++) {
    double mass, x, y, z;
    int count = fscanf(fid_xyz, "%d%lf%lf%lf%lf", &(cpu_type[n]), &x, &y, &z, &mass);
    PRINT_SCANF_ERROR(count, 5, "Reading error for xyz.in.");

    if (cpu_type[n] < 0 || cpu_type[n] >= N) {
      PRINT_INPUT_ERROR("Atom type should >= 0 and < N.");
    }

    if (mass <= 0) {
      PRINT_INPUT_ERROR("Atom mass should > 0.");
    }

    cpu_mass[n] = mass;
    cpu_position_per_atom[n] = x;
    cpu_position_per_atom[n + N] = y;
    cpu_position_per_atom[n + N * 2] = z;

    if (cpu_type[n] > number_of_types) {
      number_of_types = cpu_type[n];
    }

    if (has_velocity_in_xyz) {
      double vx, vy, vz;
      count = fscanf(fid_xyz, "%lf%lf%lf", &vx, &vy, &vz);
      PRINT_SCANF_ERROR(count, 3, "Reading error for xyz.in.");
      cpu_velocity_per_atom[n] = vx;
      cpu_velocity_per_atom[n + N] = vy;
      cpu_velocity_per_atom[n + N * 2] = vz;
    }

    for (int m = 0; m < group.size(); ++m) {
      count = fscanf(fid_xyz, "%d", &group[m].cpu_label[n]);
      PRINT_SCANF_ERROR(count, 1, "Reading error for xyz.in.");

      if (group[m].cpu_label[n] < 0 || group[m].cpu_label[n] >= N) {
        PRINT_INPUT_ERROR("Group label should >= 0 and < N.");
      }

      if (group[m].cpu_label[n] > group[m].number) {
        group[m].number = group[m].cpu_label[n];
      }
    }
  }

  for (int m = 0; m < group.size(); ++m) {
    group[m].number++;
  }

  number_of_types++;
}

void find_type_size(
  const int N,
  const int number_of_types,
  const std::vector<int>& cpu_type,
  std::vector<int>& cpu_type_size)
{
  cpu_type_size.resize(number_of_types);

  if (number_of_types == 1) {
    printf("There is only one atom type.\n");
  } else {
    printf("There are %d atom types.\n", number_of_types);
  }

  for (int m = 0; m < number_of_types; m++) {
    cpu_type_size[m] = 0;
  }
  for (int n = 0; n < N; n++) {
    cpu_type_size[cpu_type[n]]++;
  }
  for (int m = 0; m < number_of_types; m++) {
    printf("    %d atoms of type %d.\n", cpu_type_size[m], m);
  }
}

void initialize_position(
  char* input_dir,
  int& N,
  int& has_velocity_in_xyz,
  int& number_of_types,
  Box& box,
  Neighbor& neighbor,
  std::vector<Group>& group,
  Atom& atom)
{
  print_line_1();
  printf("Started initializing positions and related parameters.\n");
  print_line_2();

  char file_xyz[200];
  strcpy(file_xyz, input_dir);
  strcat(file_xyz, "/xyz.in");
  FILE* fid_xyz = my_fopen(file_xyz, "r");

  read_xyz_in_line_1(
    fid_xyz, N, neighbor.MN, neighbor.rc, box.triclinic, has_velocity_in_xyz, group);

  read_xyz_in_line_2(fid_xyz, box);

  read_xyz_in_line_3(
    fid_xyz, N, has_velocity_in_xyz, number_of_types, atom.cpu_type, atom.cpu_mass,
    atom.cpu_position_per_atom, atom.cpu_velocity_per_atom, group);

  fclose(fid_xyz);

  for (int m = 0; m < group.size(); ++m) {
    group[m].find_size(N, m);
    group[m].find_contents(N);
  }

  find_type_size(N, number_of_types, atom.cpu_type, atom.cpu_type_size);

  print_line_1();
  printf("Finished initializing positions and related parameters.\n");
  print_line_2();
}

void allocate_memory_gpu(
  const int N,
  Neighbor& neighbor,
  std::vector<Group>& group,
  Atom& atom,
  GPU_Vector<double>& thermo)
{
  neighbor.NN.resize(N);
  neighbor.NL.resize(N * neighbor.MN);
  neighbor.NN_local.resize(N);
  neighbor.NL_local.resize(N * neighbor.MN);

  neighbor.cell_count.resize(N);
  neighbor.cell_count_sum.resize(N);
  neighbor.cell_contents.resize(N);

  atom.type.resize(N);
  atom.type.copy_from_host(atom.cpu_type.data());
  for (int m = 0; m < group.size(); ++m) {
    group[m].label.resize(N);
    group[m].size.resize(group[m].number);
    group[m].size_sum.resize(group[m].number);
    group[m].contents.resize(N);
    group[m].label.copy_from_host(group[m].cpu_label.data());
    group[m].size.copy_from_host(group[m].cpu_size.data());
    group[m].size_sum.copy_from_host(group[m].cpu_size_sum.data());
    group[m].contents.copy_from_host(group[m].cpu_contents.data());
  }
  atom.mass.resize(N);
  atom.mass.copy_from_host(atom.cpu_mass.data());
  neighbor.x0.resize(N);
  neighbor.y0.resize(N);
  neighbor.z0.resize(N);
  atom.position_per_atom.resize(N * 3);
  atom.position_per_atom.copy_from_host(atom.cpu_position_per_atom.data());
  atom.velocity_per_atom.resize(N * 3);
  atom.force_per_atom.resize(N * 3);
  atom.virial_per_atom.resize(N * 9);
  atom.potential_per_atom.resize(N);
  atom.heat_per_atom.resize(N * 5);
  thermo.resize(6);
}
