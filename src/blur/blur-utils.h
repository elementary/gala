//
//  Copyright (C) 2015 Deepin Technology Co., Ltd.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

#ifndef _COMPOSITOR_BLUR_UTILS_H
#define _COMPOSITOR_BLUR_UTILS_H 

#define VERTICAL   1
#define HORIZONTAL 2

static const char* gaussian_blur_global_definition = "#define texpick texture2D\n";
static const char* gaussian_blur_glsl_declarations = "uniform vec2 resolution;";

char *build_shader(int direction, int radius, float* offsets, float *weight);
void build_gaussian_blur_kernel(int* pradius, float* offset, float* weight);

#endif /* ifndef _COMPOSITOR_BLUR_UTILS_H */
