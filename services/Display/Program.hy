public class Program {
    private static int FocusedTitlebar() {
        return 0xE5E8ED; //0x7DA7CB const
    }

	private static int UnfocusedTitlebar() {
        return 0xE5E8ED; // 0xC7CED6 const
    }

	private static int WindowBackground() {
        return 0xE5E8ED; // const
    }

	private static int WindowRadius() {
        return 12; // const
    }

	private static int WindowBorder() {
		return 0; // 8 const
	}

	private static int TitlebarHeight() {
		return 30; // const
	}

	private static int WindowResizeGrip() {
		return 10; // const
	}

	private static int TitlebarControlSize() {
		return 12; // const
	}

	private static int TopbarHeight() {
		return 30; // const
	}

	private static int ControlX(int barX, int index) {
		int size = TitlebarControlSize();
		return barX + 8 + index * (size + 10);
	}

	private static int ControlY(int barY, int barHeight) {
		return barY +
			(barHeight - TitlebarControlSize()) / 2;
	}

    private static int GpuDrawDecoratedWindow(byte[] layout, int gpuHandle, bool focused) {

        if (gpuHandle < 1 || layout[9] != 0) {
            return -95;
        }

        int x = Read16(layout, 0);
        int y = Read16(layout, 2);
        int width = Read16(layout, 4);
        int height = Read16(layout, 6);

        int header = UnfocusedTitlebar();

        if (focused) {
            header = FocusedTitlebar();
        }

        // Existing software window background.
        if (System.Australis.Gpu.FillFrameRect(x, y, width, height, WindowBackground()) != 0) {
            return -5;
        }

        // Existing titlebar geometry and colour.
        if (System.Australis.Gpu.FillFrameRect(x, y, width, TitlebarHeight(), header) != 0) {
            return -5;
        }

        // Real process-owned window content.
        if (System.Australis.Gpu.DrawWindow( gpuHandle, x, ContentTop(layout)) != 0) {
            return -5;
        }

        return 0;
    }

    private static int ProbeGpuDecoratedWindows(int firstGpu, int secondGpu, byte[] firstLayout, byte[] secondLayout, int screenWidth, int screenHeight) {

        if (firstGpu < 1 || secondGpu < 1 ||
            firstLayout[9] != 0 ||
            secondLayout[9] != 0) {
            return -22;
        }

        int ax = Read16(firstLayout, 0);
        int ay = Read16(firstLayout, 2);
        int bx = Read16(secondLayout, 0);
        int by = Read16(secondLayout, 2);

        int contentX = ax + 8;
        int contentY = ContentTop(firstLayout);

        // A point covered by A's content and B's titlebar.
        int overlapX = bx + 16;
        int overlapY = by + TitlebarHeight() / 2;

        if (overlapX < contentX ||
            overlapY < contentY ||
            overlapX >= contentX + ContentWidth(firstLayout) ||
            overlapY >= contentY + ContentHeight(firstLayout)) {
            return -22;
        }

        int firstPixel =
            System.Australis.Gpu.ReadPixel(firstGpu, 12, 12);

        int secondPixel =
            System.Australis.Gpu.ReadPixel(secondGpu, 12, 12);

        int overlapPixel =
            System.Australis.Gpu.ReadPixel(
                firstGpu,
                overlapX - contentX,
                overlapY - contentY);

        if (firstPixel < 0 || secondPixel < 0 ||
            overlapPixel < 0 ||
            NearGpuRgb(overlapPixel, FocusedTitlebar())) {
            return -5;
        }

        // Frame 1: B is above A.
        if (System.Australis.Gpu.BeginFrame(0x26384F) != 0 ||
            GpuDrawDecoratedWindow(
                firstLayout, firstGpu, false) != 0 ||
            GpuDrawDecoratedWindow(
                secondLayout, secondGpu, true) != 0 ||
            System.Australis.Gpu.FillFrameRect(
                0, 0, screenWidth, TopbarHeight(),
                0x111820) != 0 ||
            System.Australis.Gpu.EndFrame() != 0) {
            return -5;
        }

        if (!NearGpuRgb(
                System.Australis.Gpu.FramePixel(2, 2),
                0x111820) ||
            !NearGpuRgb(
                System.Australis.Gpu.FramePixel(
                    screenWidth - 2, screenHeight - 2),
                0x26384F) ||
            !NearGpuRgb(
                System.Australis.Gpu.FramePixel(
                    ax + 3, ay + TitlebarHeight() + 4),
                WindowBackground()) ||
            !NearGpuRgb(
                System.Australis.Gpu.FramePixel(
                    contentX + 12, contentY + 12),
                firstPixel) ||
            !NearGpuRgb(
                System.Australis.Gpu.FramePixel(
                    bx + 20, ContentTop(secondLayout) + 12),
                secondPixel) ||
            !NearGpuRgb(
                System.Australis.Gpu.FramePixel(
                    overlapX, overlapY),
                FocusedTitlebar())) {
            return -5;
        }

        // Frame 2: A is above B.
        if (System.Australis.Gpu.BeginFrame(0x26384F) != 0 ||
            GpuDrawDecoratedWindow(
                secondLayout, secondGpu, false) != 0 ||
            GpuDrawDecoratedWindow(
                firstLayout, firstGpu, true) != 0 ||
            System.Australis.Gpu.FillFrameRect(
                0, 0, screenWidth, TopbarHeight(),
                0x111820) != 0 ||
            System.Australis.Gpu.EndFrame() != 0) {
            return -5;
        }

        // A's content must now cover B's titlebar.
        if (!NearGpuRgb(
            System.Australis.Gpu.FramePixel(
                overlapX, overlapY),
            overlapPixel)) {
            return -5;
        }

        return 0;
    }

    private static int Paint(int x, int y, int width, int height, int rgb) {
        if (width < 1 || height < 1 || width > 2048 || height > 2048) { return -22; }
        int rows = 65536 / width;
        if (rows < 1) { return -22; }
        int drawn = 0;
        while (drawn < height) {
            int count = height - drawn;
            if (count > rows) { count = rows; }
            int result = System.Australis.Display.FillRect(x, y + drawn,
                width, count, rgb);
            if (result != 0) { return result; }
            drawn = drawn + count;
        }
        return 0;
    }

	private static int RoundedInset(int row, int width, int height, int radius) {
		if (radius > width / 2) {
			radius = width / 2;
		}

		if (radius > height / 2) {
			radius = height / 2;
		}

		if (radius <= 0 ||
			(row >= radius && row < height - radius)) {
			return 0;
		}

		int cornerY = row;

		if (row >= height - radius) {
			cornerY = height - row - 1;
		}

		int dy = radius * 2 - cornerY * 2 - 1;
		int inset = 0;

		while (inset < radius) {
			int dx = radius * 2 - inset * 2 - 1;

			if (dx * dx + dy * dy <=
				radius * radius * 4) {
				break;
			}

			inset = inset + 1;
		}

		return inset;
	}

	private static int RoundedBand(int x, int y, int width, int height, int firstRow, int lastRow, int radius, int color, byte[] clip) {
		int row = firstRow;
		int endRow = lastRow;
		int clipTop = Read16(clip, 2);
		int clipBottom = clipTop + Read16(clip, 6);

		if (row < clipTop - y) {
			row = clipTop - y;
		}

		if (endRow > clipBottom - y) {
			endRow = clipBottom - y;
		}

		if (row >= endRow) {
			return 0;
		}
		while (row < lastRow) {
			if (row >= radius && row < height - radius) {
				int end = lastRow;

				if (end > height - radius) {
					end = height - radius;
				}

				if (Clip(
					x, y + row, width,
					end - row, color, clip
				) != 0) {
					return -5;
				}

				row = end;
				continue;
			}
			int inset = RoundedInset(
				row, width, height, radius
			);

			int next = row + 1;

			while (next < lastRow &&
				RoundedInset(next, width, height, radius) == inset) {
				next = next + 1;
			}

			if (Clip(x + inset, y + row, width - inset * 2, next - row, color, clip) != 0) {
				return -5;
			}

			row = next;
		}

		return 0;
	}

    private static int GpuRoundedBand(int x, int y, int width, int height, int firstRow, int lastRow, int radius, int rgb) {

        int row = firstRow;

        while (row < lastRow) {
            int inset = RoundedInset(
                row, width, height, radius);

            int next = row + 1;

            // Combine consecutive rows with identical bounds.
            while (next < lastRow &&
                RoundedInset(
                    next, width, height, radius) == inset) {
                next = next + 1;
            }

            int span = width - inset * 2;

            if (span > 0) {
                if (System.Australis.Gpu.FillFrameRect(
                    x + inset, y + row,
                    span, next - row, rgb) != 0) {
                    return -5;
                }
            }

            row = next;
        }

        return 0;
    }

	private static int ClipWindowContent(int x, int y, int width, int height, int color, int windowX, int windowY, int windowWidth, int windowHeight, bool maximized, byte[] clip) {
		if (width <= 0 || height <= 0) {
			return 0;
		}

		// Clip to the window's rectangular bounds first.
		int left = x;
		int right = x + width;
		int first = y;
		int last = y + height;

		if (left < windowX) {
			left = windowX;
		}
		if (right > windowX + windowWidth) {
			right = windowX + windowWidth;
		}
		if (first < windowY) {
			first = windowY;
		}
		if (last > windowY + windowHeight) {
			last = windowY + windowHeight;
		}

		if (right <= left || last <= first) {
			return 0;
		}

		// Maximised windows are rectangular.
		int radius = WindowRadius();

		if (maximized || radius <= 0) {
			return Clip(
				left, first,
				right - left, last - first,
				color, clip
			);
		}

		if (radius > windowWidth / 2) {
			radius = windowWidth / 2;
		}
		if (radius > windowHeight / 2) {
			radius = windowHeight / 2;
		}

		int row = first;

		// TOP CORNERS: rounded clipping.
		while (row < last && row < windowY + radius) {
			int inset = RoundedInset(row - windowY, windowWidth, windowHeight, radius);

			int startX = left;
			int endX = right;

			if (startX < windowX + inset) {
				startX = windowX + inset;
			}
			if (endX > windowX + windowWidth - inset) {
				endX = windowX + windowWidth - inset;
			}

			if (endX > startX) {
				if (Clip(
					startX, row, endX - startX,
					1, color, clip
				) != 0) {
					return -5;
				}
			}

			row = row + 1;
		}

		// MIDDLE: one rectangular draw.
		int middleEnd = windowY + windowHeight - radius;

		if (row < last && row < middleEnd) {
			int end = last;

			if (end > middleEnd) {
				end = middleEnd;
			}

			if (Clip(left, row, right - left, end - row, color, clip) != 0) {
				return -5;
			}

			row = end;
		}

		// BOTTOM CORNERS: rounded clipping.
		while (row < last) {
			int inset = RoundedInset(row - windowY, windowWidth, windowHeight, radius);

			int startX = left;
			int endX = right;

			if (startX < windowX + inset) {
				startX = windowX + inset;
			}
			if (endX > windowX + windowWidth - inset) {
				endX = windowX + windowWidth - inset;
			}

			if (endX > startX) {
				if (Clip(startX, row, endX - startX, 1, color, clip) != 0) {
					return -5;
				}
			}

			row = row + 1;
		}

		return 0;
	}

    // Each compositor-owned layout stores x, y, width, height, visibility,
    // maximization, restore geometry, and the hovered control. Clients never
    // supply these fields.
    private static int Read16(byte[] data, int offset) {
        return data[offset] + data[offset + 1] * 256;
    }

	private static void Write16(byte[] data, int offset, int value) {
        data[offset] = (byte)(value % 256);
        data[offset + 1] = (byte)(value / 256);
    }

	private static void InitLayout(byte[] layout, int x, int y, int width, int height) {
        Write16(layout, 0, x); Write16(layout, 2, y);
        Write16(layout, 4, width); Write16(layout, 6, height);
        layout[8] = 1; layout[9] = 0; layout[18] = 0;
    }

	private static bool Visible(byte[] state, byte[] layout) {
        return state[1] == 1 && layout[8] == 1;
    }

	private static int ContentTop(byte[] layout) {
		int y = Read16(layout, 2);

		if (layout[9] == 1) {
			return y;
		}

		return y + TitlebarHeight();
	}

	private static int ContentWidth(byte[] layout) {
		return Read16(layout, 4);
	}

	private static int ContentHeight(byte[] layout) {
		int y = Read16(layout, 2);
		int height = Read16(layout, 6);

		return y + height - ContentTop(layout);
	}

	private static int UpdateTextureCell(int handle, byte[] layout, byte[] cells, int column, int row) {
        if (handle < 1 || column < 0 || column >= 4 ||
            row < 0 || row >= 4) { return -22; }
        int width = ContentWidth(layout);
        int height = ContentHeight(layout);
        int left = column * width / 4;
        int right = (column + 1) * width / 4;
        int top = row * height / 4;
        int bottom = (row + 1) * height / 4;
        int cell = (row * 4 + column) * 3;
        int rgb = cells[cell] * 65536 + cells[cell + 1] * 256 +
            cells[cell + 2];
        return System.Australis.Gpu.FillRect(handle, left, top,
            right - left, bottom - top, rgb);
    }

	private static int CreateWindowTexture(byte[] layout, byte[] cells) {
        int width = ContentWidth(layout);
        int height = ContentHeight(layout);
        if (width < 1 || height < 1) { return -22; }
        int handle = System.Australis.Gpu.Create(width, height);
        if (handle < 1) { return handle; }
        int row = 0;
        while (row < 4) {
            int column = 0;
            while (column < 4) {
                if (UpdateTextureCell(handle, layout, cells,
                    column, row) != 0) {
                    System.Australis.Gpu.Destroy(handle);
                    return -5;
                }
                column = column + 1;
            }
            row = row + 1;
        }
        return handle;
    }

	private static void CopyLayout(byte[] source, byte[] target) {
        int i = 0;
        while (i < 19) { target[i] = source[i]; i = i + 1; }
    }

	private static bool LayoutChanged(byte[] before, byte[] after) {
        int i = 0;
        while (i < 18) {
            if (before[i] != after[i]) { return true; }
            i = i + 1;
        }
        return false;
    }

	private static void ToggleMax(byte[] layout, int width, int height) {
        if (layout[9] == 0) {
            Write16(layout, 10, Read16(layout, 0));
            Write16(layout, 12, Read16(layout, 2));
            Write16(layout, 14, Read16(layout, 4));
            Write16(layout, 16, Read16(layout, 6));
			Write16(layout, 0, 0);
			Write16(layout, 2, TopbarHeight());
			Write16(layout, 4, width);
			Write16(layout, 6, height - TopbarHeight());
            layout[9] = 1;
        } else {
            Write16(layout, 0, Read16(layout, 10));
            Write16(layout, 2, Read16(layout, 12));
            Write16(layout, 4, Read16(layout, 14));
            Write16(layout, 6, Read16(layout, 16));
            layout[9] = 0;
        }
        layout[18] = 0;
    }

    // The clip also restores the small rectangle under the old cursor.
    private static void SetClip(byte[] clip, int x, int y, int width, int height) {
        clip[0] = (byte)(x % 256); clip[1] = (byte)(x / 256);
        clip[2] = (byte)(y % 256); clip[3] = (byte)(y / 256);
        clip[4] = (byte)(width % 256); clip[5] = (byte)(width / 256);
        clip[6] = (byte)(height % 256); clip[7] = (byte)(height / 256);
    }

	private static int Clip(int x, int y, int width, int height, int rgb, byte[] clip) {
        int clipX = clip[0] + clip[1] * 256;
        int clipY = clip[2] + clip[3] * 256;
        int clipWidth = clip[4] + clip[5] * 256;
        int clipHeight = clip[6] + clip[7] * 256;
        int right = x + width; int bottom = y + height;
        if (x < clipX) { x = clipX; }
        if (y < clipY) { y = clipY; }
        if (right > clipX + clipWidth) { right = clipX + clipWidth; }
        if (bottom > clipY + clipHeight) { bottom = clipY + clipHeight; }
        if (right <= x || bottom <= y) { return 0; }
        return Paint(x, y, right - x, bottom - y, rgb);
    }

	private static int DrawControl(int x, int y, int color, int kind, bool hovered, byte[] clip) {

		int size = TitlebarControlSize();

		int clipX = Read16(clip, 0);
		int clipY = Read16(clip, 2);
		int clipRight = clipX + Read16(clip, 4);
		int clipBottom = clipY + Read16(clip, 6);

		// Completely outside the damaged region?
		// Don't process this control at all.
		if (x >= clipRight || x + size <= clipX ||
			y >= clipBottom || y + size <= clipY) {
			return 0;
		}

		// Combine consecutive rows with identical circle widths.
		int row = 0;

		while (row < size) {
			int inset = ControlInset(row, size);
			int next = row + 1;

			while (next < size &&
				ControlInset(next, size) == inset) {
				next = next + 1;
			}

			int span = size - inset * 2;

			if (span > 0) {
				if (Clip(
					x + inset, y + row,
					span, next - row,
					color, clip
				) != 0) {
					return -5;
				}
			}

			row = next;
		}

		// Draw the hover icon, scaled to the button.
		if (hovered) {
			int iconSize = size * 4 / 10;
			if (iconSize < 3) {
				iconSize = 3;
			}

			int offset = (size - iconSize) / 2;
			int center = size / 2;

			if (kind == 1) {
				// Close: X
				int i = 0;

				while (i < iconSize) {
					if (Clip(
						x + offset + i,
						y + offset + i,
						1, 1, 0xFFFFFF, clip
					) != 0 ||
						Clip(
						x + offset + iconSize - i - 1,
						y + offset + i,
						1, 1, 0xFFFFFF, clip
					) != 0) {
						return -5;
					}

					i = i + 1;
				}
			} else {
				// Minimise: horizontal line
				if (Clip(
					x + offset, y + center,
					iconSize, 1, 0xFFFFFF, clip
				) != 0) {
					return -5;
				}

				if (kind == 3) {
					// Maximise: vertical line
					if (Clip(
						x + center, y + offset,
						1, iconSize, 0xFFFFFF, clip
					) != 0) {
						return -5;
					}
				}
			}
		}

		return 0;
	}

    private static int GpuDrawControl(int x, int y, int color, int kind, bool hovered) {

        int size = TitlebarControlSize();
        int row = 0;

        while (row < size) {
            int inset = ControlInset(row, size);
            int next = row + 1;

            while (next < size &&
                ControlInset(next, size) == inset) {
                next = next + 1;
            }

            int span = size - inset * 2;

            if (span > 0) {
                if (System.Australis.Gpu.FillFrameRect(
                    x + inset, y + row,
                    span, next - row, color) != 0) {
                    return -5;
                }
            }

            row = next;
        }

        // Use the same hover symbols as the software path.
        if (hovered) {
            int iconSize = size * 4 / 10;
            if (iconSize < 3) { iconSize = 3; }

            int offset = (size - iconSize) / 2;
            int center = size / 2;

            if (kind == 1) {
                int i = 0;
                while (i < iconSize) {
                    if (System.Australis.Gpu.FillFrameRect(
                        x + offset + i,
                        y + offset + i,
                        1, 1, 0xFFFFFF) != 0 ||
                        System.Australis.Gpu.FillFrameRect(
                        x + offset + iconSize - i - 1,
                        y + offset + i,
                        1, 1, 0xFFFFFF) != 0) {
                        return -5;
                    }
                    i = i + 1;
                }
            } else {
                if (System.Australis.Gpu.FillFrameRect(
                    x + offset, y + center,
                    iconSize, 1, 0xFFFFFF) != 0) {
                    return -5;
                }

                if (kind == 3) {
                    if (System.Australis.Gpu.FillFrameRect(
                        x + center, y + offset,
                        1, iconSize, 0xFFFFFF) != 0) {
                        return -5;
                    }
                }
            }
        }

        return 0;
    }

	private static int DrawControls(int x, int y, int barHeight, byte[] layout, byte[] clip) {
		int controlY = ControlY(y, barHeight);

		if (DrawControl(ControlX(x, 0), controlY, 0xFF5F57, 1, layout[18] == 1, clip) != 0 ||
			DrawControl(ControlX(x, 1), controlY, 0xFEBC2E, 2, layout[18] == 2, clip) != 0 ||
			DrawControl(ControlX(x, 2), controlY, 0x28C840, 3, layout[18] == 3, clip) != 0) {
			return -5;
		}

		return 0;
	}

    private static int GpuDrawControls(int x, int y, byte[] layout) {
        int controlY = ControlY(y, TitlebarHeight());

        if (GpuDrawControl(
            ControlX(x, 0), controlY, 0xFF5F57, 1, layout[18] == 1) != 0 ||
            GpuDrawControl(ControlX(x, 1), controlY, 0xFEBC2E, 2, layout[18] == 2) != 0 ||
            GpuDrawControl(ControlX(x, 2), controlY, 0x28C840, 3, layout[18] == 3) != 0) {
            return -5;
        }

        return 0;
    }

    private static int ControlInset(int row, int size) {
        int dy = row * 2 + 1 - size;
        int inset = 0;

        while (inset < size) {
            int dx = inset * 2 + 1 - size;

            if (dx * dx + dy * dy <= size * size) {
                break;
            }

            inset = inset + 1;
        }

        return inset;
    }

    private static int GpuDrawRoundedWindow(byte[] layout, int handle, bool focused) {

        if (handle < 1 || layout[9] != 0) {
            return -95;
        }

        int x = Read16(layout, 0);
        int y = Read16(layout, 2);
        int width = Read16(layout, 4);
        int height = Read16(layout, 6);

        int header = UnfocusedTitlebar();

        if (focused) {
            header = FocusedTitlebar();
        }

        // Entire rounded window background.
        if (GpuRoundedBand(x, y, width, height, 0, height, WindowRadius(), WindowBackground()) != 0) {
            System.Console.WriteLine("GPUDBG: rounded window background failed ");
            return -5;
        }

        // Rounded top corners; straight bottom of titlebar.
        if (GpuRoundedBand(x, y, width, height, 0, TitlebarHeight(), WindowRadius(), header) != 0) {
            System.Console.WriteLine("GPUDBG: rounded titlebar failed");
            return -5;
        }

        // Existing process-owned GPU window texture.
        if (System.Australis.Gpu.DrawWindow(handle, x, ContentTop(layout)) != 0) {
            System.Console.WriteLine("GPUDBG: rounded window texture failed");
            return -5;
        }

        // Foreground window controls.
        if (GpuDrawControls(x, y, layout) != 0) {
        	System.Console.WriteLine("GPUDBG: rounded window controls failed");
            return -5;
        }

        return 0;
    }

    private static int DrawWindow(byte[] layout, byte[] cells, byte[] clip, bool focused, int gpuHandle) {
        int x = Read16(layout, 0); int y = Read16(layout, 2);
        int width = Read16(layout, 4); int height = Read16(layout, 6);
        int top = ContentTop(layout);
		if (layout[9] == 1) {
			// Maximised windows remain square.
			if (Clip(x, y, width, height, WindowBackground(), clip) != 0) {
				return -5;
			}
		} else {
			int header = UnfocusedTitlebar();

			if (focused) {
				header = FocusedTitlebar();
			}

			int clipTop = Read16(clip, 2);
			int clipBottom = clipTop + Read16(clip, 6);

			// The titlebar completely replaces the window background
			// within its own bounds, including the rounded corners.
			bool titlebarOnly =
				clipTop >= y &&
				clipBottom <= y + TitlebarHeight();

			if (!titlebarOnly) {
				if (RoundedBand(
					x, y, width, height,
					0, height,
					WindowRadius(),
					WindowBackground(),
					clip
				) != 0) {
					return -5;
				}
			}

			//if (titlebarOnly) {
			//	System.Console.WriteLine("DBG: window body skipped");
			//} else {
			//	System.Console.WriteLine("DBG: window background complete");
			//}

			// Allow the scheduler to run between drawing stages.
			if (System.Australis.Process.Sleep(1) != 0) {
				return -5;
			}

			if (RoundedBand(x, y, width, height, 0, TitlebarHeight(), WindowRadius(), header, clip) != 0) {
				return -5;
			}

			// Reset the instruction watchdog before drawing controls.
			if (System.Australis.Process.Sleep(1) != 0) {
				return -5;
			}

			if (DrawControls(x, y, TitlebarHeight(), layout, clip) != 0) {
				return -5;
			}

		}
        int clipX = Read16(clip, 0);
        int clipY = Read16(clip, 2);
        int clipRight = clipX + Read16(clip, 4);
        int clipBottom = clipY + Read16(clip, 6);
        int contentLeft = x + 8;
        int contentRight = x + width - 8;
        int contentBottom = y + height - 8;
        int left = contentLeft;
        int upper = top;
        int right = contentRight;
        int lower = contentBottom;
        if (left < clipX) { left = clipX; }
        if (upper < clipY) { upper = clipY; }
        if (right > clipRight) { right = clipRight; }
        if (lower > clipBottom) { lower = clipBottom; }
        if (right <= left || lower <= upper) { return 0; }
        if (gpuHandle > 0 && System.Australis.Gpu.BlitRegion(gpuHandle, left - contentLeft, upper - top, right - left, lower - upper, left, upper) == 0) {
            return 0;
        }
        int row = 0;
        while (row < 4) {
            int column = 0;
            while (column < 4) {
                int left = x + WindowBorder() + column * (width - (WindowBorder() / 2)) / 4;
                int right = x + WindowBorder() + (column + 1) * (width - (WindowBorder() / 2)) / 4;
                int cellTop = top + row * (y + height - WindowBorder() - top) / 4;
                int bottom = top + (row + 1) * (y + height - WindowBorder() - top) / 4;
                int cell = (row * 4 + column) * 3;
                int rgb = cells[cell] * 65536 + cells[cell + 1] * 256 + cells[cell + 2];
                if (ClipWindowContent(left, cellTop, right - left, bottom - cellTop, rgb, x, y, width, height, layout[9] == 1, clip) != 0) {
					return -5;
				}
                column = column + 1;
            }
            row = row + 1;
        }
		System.Console.WriteLine("DBG: window content complete");
        return 0;
    }

	private static bool WindowCoversClip(byte[] layout, byte[] clip) {
		int x = Read16(layout, 0);
		int y = Read16(layout, 2);
		int width = Read16(layout, 4);
		int height = Read16(layout, 6);

		int clipX = Read16(clip, 0);
		int clipY = Read16(clip, 2);
		int clipRight = clipX + Read16(clip, 4);
		int clipBottom = clipY + Read16(clip, 6);

		// The entire damaged region must be inside this window.
		if (clipX < x || clipY < y ||
			clipRight > x + width ||
			clipBottom > y + height) {
			return false;
		}

		// Maximised windows are rectangular.
		if (layout[9] == 1) {
			return true;
		}

		// Account for the rounded corners.
		int radius = WindowRadius();

		int inset = RoundedInset(
			clipY - y, width, height, radius
		);

		int bottomInset = RoundedInset(
			clipBottom - y - 1, width, height, radius
		);

		if (bottomInset > inset) {
			inset = bottomInset;
		}

		return clipX >= x + inset &&
			clipRight <= x + width - inset;
	}

    private static int Compose(int width, int height, byte[] firstState, byte[] firstCells, byte[] firstLayout, byte[] secondState, byte[] secondCells, byte[] secondLayout, byte[] clip, int focused, int top, int firstGpu, int secondGpu) {
		if (Clip(0, 0, width, height, 0x26384F, clip) != 0) {
			return -5;
		}

		if (top == 1) {
			// First window is on top.
			bool covered = Visible(firstState, firstLayout) &&
				WindowCoversClip(firstLayout, clip);

			// Draw the rear window only if some of it is visible.
			if (!covered && Visible(secondState, secondLayout) &&
				DrawWindow(secondLayout, secondCells, clip,
					focused == 2, secondGpu) != 0) {
				return -5;
			}

			if (Visible(firstState, firstLayout) &&
				DrawWindow(firstLayout, firstCells, clip,
					focused == 1, firstGpu) != 0) {
				return -5;
			}

		} else {
			// Second window is on top.
			bool covered = Visible(secondState, secondLayout) &&
				WindowCoversClip(secondLayout, clip);

			if (!covered && Visible(firstState, firstLayout) &&
				DrawWindow(firstLayout, firstCells, clip,
					focused == 1, firstGpu) != 0) {
				return -5;
			}

			if (Visible(secondState, secondLayout) &&
				DrawWindow(secondLayout, secondCells, clip,
					focused == 2, secondGpu) != 0) {
				return -5;
			}
		}
        int maxId = 0;
        if (top == 1 && Visible(firstState, firstLayout) &&
            firstLayout[9] == 1) { maxId = 1; }
        if (top == 2 && Visible(secondState, secondLayout) &&
            secondLayout[9] == 1) { maxId = 2; }
        int bar = 0x111820;
        if (maxId > 0) { bar = 0x000000; }
        if (Clip(0, 0, width, TopbarHeight(), bar, clip) != 0) {
			return -5;
		}
		if (maxId == 1 && DrawControls(0, 0, TopbarHeight(), firstLayout, clip) != 0) {
			return -5;
		}
		if (maxId == 2 && DrawControls(0, 0, TopbarHeight(), secondLayout, clip) != 0) {
			return -5;
		}
        if (firstState[1] == 1) {
            int color = 0xCB3830;
            if (firstLayout[8] == 0) { color = 0x617080; }
            if (Clip(width - 80, 8, 32, 16, color, clip) != 0) {
                return -5;
            }
        }
        if (secondState[1] == 1) {
            int color = 0x2A68D9;
            if (secondLayout[8] == 0) { color = 0x617080; }
            if (Clip(width - 44, 8, 32, 16, color, clip) != 0) {
                return -5;
            }
        }
        return 0;
    }

    private static int Cursor(int x, int y) {
        int row = 0;
        while (row < 14) {
            int span = row / 2 + 2;
            if (Paint(x, y + row, span, 1, 0x101820) != 0) { return -5; }
            if (span > 2 && Paint(x + 1, y + row, span - 2, 1,
                0xFFFFFF) != 0) { return -5; }
            row = row + 1;
        }
        if (Paint(x + 3, y + 14, 3, 6, 0x101820) != 0 ||
            Paint(x + 4, y + 14, 1, 5, 0xFFFFFF) != 0) { return -5; }
        return 0;
    }

	private static int ComposeGpuTile(int handle, int target, byte[] cells) {
        if (handle < 1) { return 0; }
        int rgb = cells[0] * 65536 + cells[1] * 256 + cells[2];
        int cleared = System.Australis.Gpu.Clear(handle, rgb);
        int blit = -1;
        if (cleared == 0) {
            blit = System.Australis.Gpu.Blit(handle, 30, 100);
        }
        if (cleared != 0 || blit != 0) {
            System.Console.WriteLine(
                "Display: GPU tile unavailable; software frame kept");
            return 0;
        }
        if (System.Australis.Gpu.BlitRegion(handle, 2, 2, 1, 1, 30, 100) != 0 || System.Australis.Gpu.BlitRegion(handle, 7, 7, 2, 1, 30, 100) != -22) {
            System.Console.WriteLine("Display: GPU region blit failed");
            return -5;
        }
        System.Console.WriteLine("Display: GPU region blit passed");
        if (target > 0) {
            if (System.Australis.Gpu.FillRect(handle,
                    2, 2, 1, 1, 0x123456) != 0 ||
                System.Australis.Gpu.CopyRegion(handle,
                    target, 2, 2, 1, 1, 0, 0) != 0 ||
                System.Australis.Gpu.ReadPixel(target, 0, 0) != 0x123456 ||
                System.Australis.Gpu.CopyRegion(handle,
                    target, 7, 7, 2, 1, 0, 0) != -22 ||
                System.Australis.Gpu.FillRect(target,
                    0, 0, 1, 1, rgb) != 0) {
                System.Console.WriteLine("Display: GPU texture copy failed");
                return -5;
            }
            System.Console.WriteLine("Display: GPU texture copy passed");
        }
        System.Console.WriteLine("Display: GPU tile composed to scanout");
        return 0;
    }

    // Version 2: create [1,R,G,B], update [2,id,col,row,R,G,B],
    // close [3,id]. The kernel binds each channel to one child PID.
    // A client can update only the ID assigned to its own channel.
    private static int Handle(int channel, int id, byte[] state, byte[] cells, byte[] message, byte[] reply) {
        if (System.Australis.Channel.Peer(channel) < 1) {
            if (state[1] == 1) { state[1] = 0; return 1; }
            return 0;
        }
        int length = System.Australis.Channel.Receive(channel, message);
        if (length < 1) { return 0; }
        reply[0] = message[0]; reply[1] = 0;
        int changed = 0;
        if (length == 4 && message[0] == 1 && state[1] == 0) {
            int i = 0;
            while (i < 16) {
                cells[i * 3] = message[1]; cells[i * 3 + 1] = message[2];
                cells[i * 3 + 2] = message[3]; i = i + 1;
            }
            state[0] = (byte)id; state[1] = 1; state[3] = 0;
            reply[1] = (byte)id; changed = 1;
        } else if (length == 7 && message[0] == 2) {
            if (state[1] == 1 && message[1] == id &&
                message[2] < 4 && message[3] < 4) {
                int cell = (message[3] * 4 + message[2]) * 3;
                cells[cell] = message[4]; cells[cell + 1] = message[5];
                cells[cell + 2] = message[6];
                state[3] = 1; state[6] = message[2]; state[7] = message[3];
                reply[1] = 1; changed = 2;
            } else { state[4] = 1; }
        } else if (length == 2 && message[0] == 3 &&
            message[1] == id && state[1] == 1) {
            state[1] = 0; state[3] = 0; state[5] = 1;
            reply[1] = 1; changed = 1;
        }
        if (System.Australis.Channel.Send(channel, 2, reply) != 0) { return -5; }
        return changed;
    }

    // A bounded list of clipped damage rectangles. If more than sixteen
    // regions accumulate, repaint the screen once.
    private static void Damage(byte[] dirty, int x, int y, int width, int height, int displayWidth, int displayHeight) {
        if (width < 1 || height < 1 || x >= displayWidth ||
            y >= displayHeight) { return; }
        if (x < 0) { width = width + x; x = 0; }
        if (y < 0) { height = height + y; y = 0; }
        if (x + width > displayWidth) { width = displayWidth - x; }
        if (y + height > displayHeight) { height = displayHeight - y; }
        if (width < 1 || height < 1) { return; }
        int count = dirty[0];
        if (count == 1 && Read16(dirty, 1) == 0 &&
            Read16(dirty, 3) == 0 &&
            Read16(dirty, 5) == displayWidth &&
            Read16(dirty, 7) == displayHeight) { return; }
        if (x == 0 && y == 0 && width == displayWidth &&
            height == displayHeight) { count = 0; }
        int region = 0;
        while (region < count) {
            int prior = 1 + region * 8;
            int priorX = Read16(dirty, prior);
            int priorY = Read16(dirty, prior + 2);
            int priorWidth = Read16(dirty, prior + 4);
            int priorHeight = Read16(dirty, prior + 6);
            if (priorX <= x && priorY <= y &&
                priorX + priorWidth >= x + width &&
                priorY + priorHeight >= y + height) { return; }
            if (x <= priorX && y <= priorY &&
                x + width >= priorX + priorWidth &&
                y + height >= priorY + priorHeight) {
                int move = region;
                while (move + 1 < count) {
                    int part = 0;
                    while (part < 8) {
                        dirty[1 + move * 8 + part] =
                            dirty[1 + (move + 1) * 8 + part];
                        part = part + 1;
                    }
                    move = move + 1;
                }
                count = count - 1;
            } else { region = region + 1; }
        }
        if (count >= 16) {
            count = 0; x = 0; y = 0;
            width = displayWidth; height = displayHeight;
        }
        int offset = 1 + count * 8;
        dirty[offset] = (byte)(x % 256);
        dirty[offset + 1] = (byte)(x / 256);
        dirty[offset + 2] = (byte)(y % 256);
        dirty[offset + 3] = (byte)(y / 256);
        dirty[offset + 4] = (byte)(width % 256);
        dirty[offset + 5] = (byte)(width / 256);
        dirty[offset + 6] = (byte)(height % 256);
        dirty[offset + 7] = (byte)(height / 256);
        dirty[0] = (byte)(count + 1);
    }

    private static void DamageLayout(byte[] dirty, byte[] layout, int width, int height) {
        if (layout[8] == 1) {
            Damage(dirty, Read16(layout, 0), Read16(layout, 2),
                Read16(layout, 4), Read16(layout, 6), width, height);
        }
    }

	private static void DamageTransition(byte[] dirty, byte[] before, byte[] after, int width, int height) {
        if (before[8] == 0) {
            DamageLayout(dirty, after, width, height); return;
        }
        if (after[8] == 0) {
            DamageLayout(dirty, before, width, height); return;
        }
        int left = Read16(before, 0); int top = Read16(before, 2);
        int right = left + Read16(before, 4);
        int bottom = top + Read16(before, 6);
        int nextX = Read16(after, 0); int nextY = Read16(after, 2);
        if (nextX < left) { left = nextX; }
        if (nextY < top) { top = nextY; }
        if (nextX + Read16(after, 4) > right) {
            right = nextX + Read16(after, 4);
        }
        if (nextY + Read16(after, 6) > bottom) {
            bottom = nextY + Read16(after, 6);
        }
        Damage(dirty, left, top, right - left, bottom - top,
            width, height);
    }

	private static void DamageOverlap(byte[] dirty, byte[] first, byte[] second, int width, int height) {
        if (first[8] == 0 || second[8] == 0) { return; }
        int left = Read16(first, 0); int top = Read16(first, 2);
        int right = left + Read16(first, 4);
        int bottom = top + Read16(first, 6);
        int otherX = Read16(second, 0); int otherY = Read16(second, 2);
        if (left < otherX) { left = otherX; }
        if (top < otherY) { top = otherY; }
        if (right > otherX + Read16(second, 4)) {
            right = otherX + Read16(second, 4);
        }
        if (bottom > otherY + Read16(second, 6)) {
            bottom = otherY + Read16(second, 6);
        }
        Damage(dirty, left, top, right - left, bottom - top,
            width, height);
    }

	private static void DamageCell(byte[] dirty, byte[] state, byte[] layout, int width, int height) {
        if (!Visible(state, layout)) { return; }
        int x = Read16(layout, 0); int y = Read16(layout, 2);
        int windowWidth = Read16(layout, 4);
        int windowHeight = Read16(layout, 6);
        int contentTop = ContentTop(layout);
        int col = state[6]; int row = state[7];
        int left = x + 8 + col * (windowWidth - 16) / 4;
        int right = x + 8 + (col + 1) * (windowWidth - 16) / 4;
        int top = contentTop + row *
            (y + windowHeight - 8 - contentTop) / 4;
        int bottom = contentTop + (row + 1) *
            (y + windowHeight - 8 - contentTop) / 4;
        Damage(dirty, left, top, right - left, bottom - top, width, height);
    }

    private static bool HitWindow(int x, int y, byte[] state, byte[] layout) {
        if (!Visible(state, layout)) { return false; }
        int left = Read16(layout, 0); int top = Read16(layout, 2);
        int width = Read16(layout, 4); int height = Read16(layout, 6);
        if (x < left || x >= left + width || y < top || y >= top + height) {
			return false;
		}
		if (layout[9] == 0) {
			int localX = x - left;
			int localY = y - top;

			int inset = RoundedInset(
				localY, width, height, WindowRadius()
			);

			if (localX < inset || localX >= width - inset) {
				return false;
			}
		}
        return true;
    }

	private static int Hit(int x, int y, byte[] firstState, byte[] firstLayout, byte[] secondState, byte[] secondLayout, int top) {
		if (top == 1) {
			if (Visible(firstState, firstLayout) && (ResizeEdges(x, y, firstLayout) != 0 || HitWindow(x, y, firstState, firstLayout))) {
				return 1;
			}

			if (Visible(secondState, secondLayout) && (ResizeEdges(x, y, secondLayout) != 0 || HitWindow(x, y, secondState, secondLayout))) {
				return 2;
			}
		} else {
			if (Visible(secondState, secondLayout) && (ResizeEdges(x, y, secondLayout) != 0 || HitWindow(x, y, secondState, secondLayout))) {
				return 2;
			}

			if (Visible(firstState, firstLayout) && (ResizeEdges(x, y, firstLayout) != 0 || HitWindow(x, y, firstState, firstLayout))) {
				return 1;
			}
		}

		return 0;
	}

    private static bool ContentHit(int x, int y, byte[] layout) {
        int left = Read16(layout, 0); int top = Read16(layout, 2);
        int width = Read16(layout, 4); int height = Read16(layout, 6);
        return x >= left + 8 && x < left + width - 8 &&
            y >= ContentTop(layout) && y < top + height - 8;
    }

    private static void HeaderDamage(byte[] dirty, byte[] layout,
        int width, int height) {
        if (layout[8] == 0) { return; }
        if (layout[9] == 1) {
            Damage(dirty, 0, 0, width, TopbarHeight(), width, height);
        } else {
            Damage(dirty, Read16(layout, 0), Read16(layout, 2),
                Read16(layout, 4), TitlebarHeight(), width, height);
        }
    }

	private static void ControlDamage(byte[] dirty, byte[] layout, int control, int width, int height) {

		if (layout[8] == 0 || control < 1 || control > 3) {
			return;
		}

		int x = Read16(layout, 0);
		int y = Read16(layout, 2);
		int barHeight = TitlebarHeight();

		if (layout[9] == 1) {
			x = 0;
			y = 0;
			barHeight = TopbarHeight();
		}

		int padding = 2;

		Damage(
			dirty,
			ControlX(x, control - 1) - padding,
			ControlY(y, barHeight) - padding,
			TitlebarControlSize() + padding * 2,
			TitlebarControlSize() + padding * 2,
			width, height
		);
	}

	private static int MenuHit(int x, int y, int width,
        byte[] firstState, byte[] secondState) {
        if (y < 8 || y >= 24) { return 0; }
        if (x >= width - 80 && x < width - 48 &&
            firstState[1] == 1) { return 1; }
        if (x >= width - 44 && x < width - 12 &&
            secondState[1] == 1) { return 2; }
        return 0;
    }

	private static int ControlHit(int x, int y, byte[] layout) {
		int left = Read16(layout, 0);
		int top = Read16(layout, 2);
		int barHeight = TitlebarHeight();
		if (layout[9] == 1) {
			left = 0;
			top = 0;
			barHeight = TopbarHeight();
		}
		int size = TitlebarControlSize();
		int controlY = ControlY(top, barHeight);
		if (y < controlY || y >= controlY + size) {
			return 0;
		}
		int index = 0;
		while (index < 3) {
			int controlX = ControlX(left, index);
			if (x >= controlX && x < controlX + size) {
				return index + 1;
			}
			index = index + 1;
		}

		return 0;
	}

	private static int ResizeEdges(int x, int y, byte[] layout) {
		if (layout[9] == 1 || layout[8] == 0) {
			return 0;
		}

		int left = Read16(layout, 0);
		int top = Read16(layout, 2);
		int right = left + Read16(layout, 4);
		int bottom = top + Read16(layout, 6);

		if (x < left || x >= right ||
			y < top || y >= bottom) {
			return 0;
		}

		int grip = WindowResizeGrip();
		int edges = 0;

		if (x < left + grip) {
			edges = edges + 1;
		} else if (x >= right - grip) {
			edges = edges + 2;
		}

		if (y < top + grip) {
			edges = edges + 4;
		} else if (y >= bottom - grip) {
			edges = edges + 8;
		}

		return edges;
	}

	private static bool TitleHit(int x, int y, byte[] layout) {
		if (layout[9] == 1) {
			return false;
		}
		int left = Read16(layout, 0);
		int top = Read16(layout, 2);
		int controlsEnd = ControlX(left, 2) + TitlebarControlSize() + 12;
		return x >= controlsEnd && x < left + Read16(layout, 4) - 12 && y >= top && y < top + TitlebarHeight();
	}

    // Kinds: 1 move, 2 down, 3 up. Coordinates are clipped to the
    // target's content and never name another client's surface.
    private static void Pointer(int id, int kind, int x, int y, byte[] firstLayout, byte[] secondLayout, int firstChannel, int secondChannel, byte[] event) {
        if (id < 1) { return; }
        byte[] layout = firstLayout; int channel = firstChannel;
        if (id == 2) {
            layout = secondLayout; channel = secondChannel;
        }
        int localX = x - Read16(layout, 0) - 8;
        int localY = y - ContentTop(layout);
        if (localX < 0) { localX = 0; }
        if (localY < 0) { localY = 0; }
        int maxX = Read16(layout, 4) - 17;
        int maxY = Read16(layout, 2) + Read16(layout, 6) - 9 -
            ContentTop(layout);
        if (localX > maxX) { localX = maxX; }
        if (localY > maxY) { localY = maxY; }
        event[0] = 4; event[1] = (byte)id; event[2] = (byte)kind;
        event[3] = (byte)(localX % 256);
        event[4] = (byte)(localX / 256);
        event[5] = (byte)(localY % 256);
        event[6] = (byte)(localY / 256);
        int sent = System.Australis.Channel.Send(channel, 2, event);
    }

    private static int Flush(byte[] dirty, byte[] clip, int width, int height, byte[] firstState, byte[] firstCells, byte[] firstLayout, byte[] secondState, byte[] secondCells, byte[] secondLayout, int focused, int top, int cursorX, int cursorY, bool hardwareCursor, int firstGpu, int secondGpu) {
        int count = dirty[0];
        int opened = System.Australis.Display.BeginFrame();
        int waits = 0;
        while (opened == -11 && waits < 100) {
            if (System.Australis.Process.Sleep(1) != 0) { return -5; }
            opened = System.Australis.Display.BeginFrame();
            waits = waits + 1;
        }
        if (opened != 0) { return -5; }
        int i = 0;
        while (i < count) {
            // The backbuffer keeps this frame private while a large batch
            // cooperatively yields between regions.
            if (System.Australis.Process.Sleep(1) != 0) { return -5; }
            int offset = 1 + i * 8;
            int x = dirty[offset] + dirty[offset + 1] * 256;
            int y = dirty[offset + 2] + dirty[offset + 3] * 256;
            int rectWidth = dirty[offset + 4] + dirty[offset + 5] * 256;
			int rectHeight = dirty[offset + 6] + dirty[offset + 7] * 256;

			System.Console.Write("PERF: dirty x=");
			System.Console.Write(x);
			System.Console.Write(" y=");
			System.Console.Write(y);
			System.Console.Write(" w=");
			System.Console.Write(rectWidth);
			System.Console.Write(" h=");
			System.Console.WriteLine(rectHeight);

			SetClip(clip, x, y, rectWidth, rectHeight);
			System.Console.WriteLine("PERF: compose START");
            if (Compose(width, height, firstState, firstCells,
                firstLayout, secondState, secondCells, secondLayout,
                clip, focused, top, firstGpu, secondGpu) != 0) {
                return -5;
            }
			System.Console.WriteLine("PERF: compose END");
            if (!hardwareCursor && x < cursorX + 14 &&
                x + rectWidth > cursorX &&
                y < cursorY + 20 && y + rectHeight > cursorY &&
                Cursor(cursorX, cursorY) != 0) { return -5; }
            i = i + 1;
        }
        if (System.Australis.Display.PresentFrame() != 0) { return -5; }
        dirty[0] = 0;
        return waits;
    }

	private static int FlushRetained(byte[] dirty, int width, int height, int cursorX, int cursorY, bool hardwareCursor) {

		int count = dirty[0];
		if (count == 0) { return 0; }

		int opened = System.Australis.Display.BeginFrame();
		int waits = 0;

		while (opened == -11 && waits < 100) {
			if (System.Australis.Process.Sleep(1) != 0) {
				return -5;
			}

			opened = System.Australis.Display.BeginFrame();
			waits = waits + 1;
		}

		if (opened != 0) {
			System.Console.Write("Display: retained BeginFrame failed: ");
			System.Console.WriteLine(opened);
			return -5;
		}

		bool cursorDamaged = false;
		int i = 0;

		while (i < count) {
			int offset = 1 + i * 8;

			int x = dirty[offset] +
				dirty[offset + 1] * 256;

			int y = dirty[offset + 2] +
				dirty[offset + 3] * 256;

			int rectWidth = dirty[offset + 4] +
				dirty[offset + 5] * 256;

			int rectHeight = dirty[offset + 6] +
				dirty[offset + 7] * 256;

			if (x < 0 || y < 0 ||
				rectWidth < 1 || rectHeight < 1 ||
				x > width - rectWidth ||
				y > height - rectHeight) {
				return -5;
			}

			if (!hardwareCursor &&
				x < cursorX + 14 &&
				x + rectWidth > cursorX &&
				y < cursorY + 20 &&
				y + rectHeight > cursorY) {
				cursorDamaged = true;
			}

			int result = System.Australis.Display.RetainedComposeRect(x, y, rectWidth, rectHeight);

			if (result != 0) {
				System.Console.Write("Display: retained ComposeRect failed: ");
				System.Console.WriteLine(result);
				return -5;
			}

			i = i + 1;
		}

		int cursorResult = Cursor(cursorX, cursorY);
		if (cursorResult != 0) {
			System.Console.Write("Display: retained cursor failed: ");
			System.Console.WriteLine(cursorResult);
			return -5;
		}

		int presentResult = System.Australis.Display.PresentFrame();
		if (presentResult != 0) {
			System.Console.Write("Display: retained PresentFrame failed: ");
			System.Console.WriteLine(presentResult);
			return -5;
		}

		dirty[0] = 0;
		return waits;
	}

    private static int SubmitWithWait(int handle) {
        int submitted = System.Australis.Display.SubmitBuffer(handle);
        int waits = 0;
        while (submitted == -11 && waits < 100) {
            if (System.Australis.Process.Sleep(1) != 0) { return -5; }
            submitted = System.Australis.Display.SubmitBuffer(handle);
            waits = waits + 1;
        }
        return submitted;
    }

    private static int CheckBuffers(int width, int height) {
        int first = System.Australis.Display.AllocateBuffer(width, height,
            width * 4, 1);
        int second = System.Australis.Display.AllocateBuffer(width, height,
            width * 4, 1);
        if (first < 1 || second <= first ||
            System.Australis.Display.BeginBuffer(first) != 0 ||
            System.Australis.Display.BeginBuffer(second) != 0 ||
            System.Australis.Display.FillBufferRect(first, 0, 0, 1, 1,
                0x123456) != 0 ||
            System.Australis.Display.FillBufferRect(second, 0, 0, 1, 1,
                0x654321) != 0) { return -1; }
        int firstFence = SubmitWithWait(first);
        if (firstFence < 1 ||
            System.Australis.Display.BufferCompletion(first,
                firstFence) != 1 ||
            System.Australis.Display.BeginBuffer(first) != -16 ||
            System.Australis.Display.DestroyBuffer(first) != -16) {
            return -1;
        }
        int secondFence = SubmitWithWait(second);
        if (secondFence <= firstFence ||
            System.Australis.Display.BufferCompletion(second,
                secondFence) != 1 ||
            System.Australis.Display.ReleaseBuffer(first,
                firstFence) != 0 ||
            System.Australis.Display.ReleaseBuffer(second,
                secondFence) != 0 ||
            System.Australis.Display.DestroyBuffer(first) != 0 ||
            System.Australis.Display.DestroyBuffer(second) != 0) {
            return -1;
        }
        System.Console.WriteLine("Display: two owned buffers completed and released");
        return 0;
    }

	private static int RetainedWindowId(byte[] ids, int offset) {

		return Read16(ids, offset) +
			Read16(ids, offset + 2) * 65536;
	}

	private static int SyncRetainedWindow(byte[] ids, int idOffset, byte[] before, byte[] current, byte[] cells, int gpuHandle, bool contentChanged) {
		int windowId = RetainedWindowId(ids, idOffset);
		if (windowId < 1) {
			return -22;
		}

		// Refresh the cached content only when it changes.
		if (contentChanged) {
            int submitted = -19;
            if (gpuHandle > 0) {
                submitted = System.Australis.Display.RetainedSubmitGpu(
                    windowId, gpuHandle);
            } else {
                submitted = System.Australis.Display.RetainedSubmitCells(
                    windowId, cells);
            }

            if (submitted != 0) {
                return submitted;
            }
        }

		// Moving a window must not require resubmitting pixels.
		if (Read16(before, 0) != Read16(current, 0) || Read16(before, 2) != Read16(current, 2)) {
			return System.Australis.Display.RetainedMove(windowId, Read16(current, 0), Read16(current, 2));
		}

		return 0;
	}

	private static int SyncRetainedGeometry(int windowId, byte[] before, byte[] current) {
		if (windowId < 1) { return -22; }
		if (before[9] != current[9]) {
			if (current[9] == 1) {
				return System.Australis.Display.RetainedMaximize(
					windowId);
			}

			return System.Australis.Display.RetainedUnmaximize(
				windowId);
		}

		if (current[9] == 1) {
			return 0;
		}

		int oldX = Read16(before, 0);
		int oldY = Read16(before, 2);
		int oldWidth = Read16(before, 4);
		int oldHeight = Read16(before, 6);

		int x = Read16(current, 0);
		int y = Read16(current, 2);
		int width = Read16(current, 4);
		int height = Read16(current, 6);

		if (oldX == x && oldY == y &&
			oldWidth == width && oldHeight == height) {
			return 0;
		}

		// Shrink first, then move, then grow.
		// This avoids temporary out-of-bounds geometry
		// when resizing from the left or top edge.
		int intermediateWidth = oldWidth;
		int intermediateHeight = oldHeight;

		if (width < intermediateWidth) {
			intermediateWidth = width;
		}

		if (height < intermediateHeight) {
			intermediateHeight = height;
		}

		if (intermediateWidth != oldWidth ||
			intermediateHeight != oldHeight) {

			if (System.Australis.Display.RetainedResize(
				windowId,
				intermediateWidth,
				intermediateHeight) != 0) {
				return -5;
			}
		}

		if (x != oldX || y != oldY) {
			if (System.Australis.Display.RetainedMove(
				windowId, x, y) != 0) {
				return -5;
			}
		}

		if (width != intermediateWidth ||
			height != intermediateHeight) {

			if (System.Australis.Display.RetainedResize(
				windowId, width, height) != 0) {
				return -5;
			}
		}

		return 0;
	}

	private static int StageRetainedWindows(byte[] firstLayout, byte[] secondLayout, byte[] firstCells, byte[] secondCells, int firstGpu, int secondGpu, byte[] windowIds) {

		int enabled =
			System.Australis.Display.RetainedEnable(
				TopbarHeight());

		if (enabled != 0) {
			return enabled;
		}

		int firstWindow =
			System.Australis.Display.RetainedOpen(
				Read16(firstLayout, 0),
				Read16(firstLayout, 2),
				Read16(firstLayout, 4),
				Read16(firstLayout, 6));

		if (firstWindow < 1) {
			return firstWindow;
		}

		int secondWindow =
			System.Australis.Display.RetainedOpen(
				Read16(secondLayout, 0),
				Read16(secondLayout, 2),
				Read16(secondLayout, 4),
				Read16(secondLayout, 6));

		if (secondWindow < 1) {
			return secondWindow;
		}

		int firstSubmit = -19;
        if (firstGpu > 0) {
            firstSubmit = System.Australis.Display.RetainedSubmitGpu(
                firstWindow, firstGpu);
        } else {
            firstSubmit = System.Australis.Display.RetainedSubmitCells(
                firstWindow, firstCells);
        }

        int secondSubmit = -19;
        if (secondGpu > 0) {
            secondSubmit = System.Australis.Display.RetainedSubmitGpu(
                secondWindow, secondGpu);
        } else {
            secondSubmit = System.Australis.Display.RetainedSubmitCells(
                secondWindow, secondCells);
        }

		if (firstSubmit != 0) {
			return firstSubmit;
		}

		if (secondSubmit != 0) {
			return secondSubmit;
		}

		// The second window starts on top.
		if (System.Australis.Display.RetainedFocus(
				secondWindow) != 0) {
			return -5;
		}

		// Exercise the movement bridge without changing geometry.
		if (System.Australis.Display.RetainedMove(
				firstWindow,
				Read16(firstLayout, 0),
				Read16(firstLayout, 2)) != 0) {
			return -5;
		}

		if (System.Australis.Display.RetainedHover(
				-1, -1) != 0) {
			return -5;
		}


		Write16(windowIds, 0, firstWindow % 65536);
		Write16(windowIds, 2, firstWindow / 65536);

		Write16(windowIds, 4, secondWindow % 65536);
		Write16(windowIds, 6, secondWindow / 65536);

		return 0;

	}

    public static int Main(string[] args) {
        int width = System.Australis.SystemInfo.Query(23);
        int height = System.Australis.SystemInfo.Query(24);
        if (width < 320 || width > 2048 || height < 240 ||
            height > 2048 || width * height > 1048576) { return 1; }
        if (System.Australis.Display.Acquire() != 0) { return 2; }
        int gpuHandle = System.Australis.Gpu.Create(8, 8);
        if (gpuHandle > 0) {
            int second = System.Australis.Gpu.Create(8, 8);
            int third = System.Australis.Gpu.Create(8, 8);
            int fourth = System.Australis.Gpu.Create(8, 8);
            int cleared = System.Australis.Gpu.Clear(gpuHandle, 0x228844);
            int firstPixel = System.Australis.Gpu.ReadPixel(gpuHandle, 0, 0);
            int filled = System.Australis.Gpu.FillRect(gpuHandle,
                1, 1, 2, 2, 0x335577);
            int changedPixel = System.Australis.Gpu.ReadPixel(gpuHandle,
                1, 1);
            int destroyed = System.Australis.Gpu.Destroy(gpuHandle);
            int secondDestroyed = System.Australis.Gpu.Destroy(second);
            int thirdDestroyed = System.Australis.Gpu.Destroy(third);
            int stale = System.Australis.Gpu.Clear(gpuHandle, 0);
            if (second < 1 || third < 1 || fourth != -12 ||
                secondDestroyed != 0 || thirdDestroyed != 0 ||
                cleared != 0 ||
                firstPixel < 0x218743 || firstPixel > 0x238945 ||
                filled != 0 || changedPixel < 0x325476 ||
                changedPixel > 0x345678 || destroyed != 0 ||
                stale != -13) {
                int released = System.Australis.Display.Release();
                return 10;
            }
            System.Console.WriteLine("Display: isolated GPU resource operations passed");
            gpuHandle = System.Australis.Gpu.Create(8, 8);
            if (gpuHandle < 1) {
                int released = System.Australis.Display.Release();
                return 10;
            }
        } else if (gpuHandle != -19) {
            int released = System.Australis.Display.Release(); return 10;
        }
		int initialMode = System.Australis.Display.SetMode(width, height);

		if (initialMode != -95 && initialMode != 0) {
			int released = System.Australis.Display.Release();
			return 8;
		}

		// GOP does not support the VirtIO-GPU scanout restoration API.
		bool gpuScanoutSupported = initialMode == 0;

		bool hardwareCursor = System.Australis.SystemInfo.Query(29) / 4 % 2 == 1;
        if (CheckBuffers(width, height) != 0) {
            int released = System.Australis.Display.Release(); return 9;
        }
		System.Console.WriteLine("DBG 1: starting demo clients");
        int firstPid = System.Australis.Process.Spawn("/System/Core/DisplayDemoA.exec");
        int secondPid = System.Australis.Process.Spawn("/System/Core/DisplayDemoB.exec");
        if (firstPid < 1 || secondPid < 1) {
            int released = System.Australis.Display.Release(); return 3;
        }
		System.Console.WriteLine("DBG 2: channels opened");
        int firstChannel = System.Australis.Channel.Open(firstPid, 2);
        int secondChannel = System.Australis.Channel.Open(secondPid, 2);
        if (firstChannel < 1 || secondChannel < 1) {
            int released = System.Australis.Display.Release(); return 4;
        }
        byte[] firstState = new byte[8]; byte[] secondState = new byte[8];
        byte[] firstCells = new byte[48]; byte[] secondCells = new byte[48];
        byte[] message = new byte[7]; byte[] reply = new byte[2];
        int rounds = 0;
        while (rounds < 1000 && (firstState[3] == 0 || secondState[3] == 0 ||
            firstState[4] == 0 || secondState[4] == 0 ||
            secondState[5] == 0)) {
            if (Handle(firstChannel, 1, firstState, firstCells,
                    message, reply) < 0 ||
                Handle(secondChannel, 2, secondState, secondCells,
                    message, reply) < 0) {
                System.Console.WriteLine("Display: client handshake failed");
                int released = System.Australis.Display.Release(); return 5;
            }
            int slept = System.Australis.Process.Sleep(1);
            rounds = rounds + 1;
        }
        if (firstState[1] != 1 || secondState[1] != 1 ||
            firstState[3] == 0 || secondState[3] == 0 ||
            firstState[4] == 0 || secondState[4] == 0 ||
            secondState[5] == 0) {
            System.Console.WriteLine("Display: client startup timed out");
            int released = System.Australis.Display.Release(); return 5;
        }
		System.Console.WriteLine("DBG 3: clients ready");
        int windowWidth = width / 2 - 30;
        int windowHeight = height / 2;
        if (windowWidth < 96 || windowHeight < 80 ||
            width / 3 + windowWidth > width ||
            72 + windowHeight > height) {
            int released = System.Australis.Display.Release(); return 6;
        }
        if (gpuHandle > 0) {
            int windowTexture = System.Australis.Gpu.Create(
                windowWidth, windowHeight);
            int windowClear = -1; int windowPixel = -1;
            if (windowTexture > 0) {
                windowClear = System.Australis.Gpu.Clear(windowTexture,
                    0x31658C);
                windowPixel = System.Australis.Gpu.ReadPixel(windowTexture,
                    windowWidth - 1, windowHeight - 1);
            }
            int windowDestroy = -1;
            if (windowTexture > 0) {
                windowDestroy = System.Australis.Gpu.Destroy(windowTexture);
            }
            if (windowTexture < 1 || windowClear != 0 ||
                windowPixel < 0x30648B ||
                windowPixel > 0x32668D ||
                windowDestroy != 0) {
                System.Console.Write("Display: window texture failed ");
                System.Console.Write(windowTexture);
                System.Console.Write(" ");
                System.Console.Write(windowClear);
                System.Console.Write(" ");
                System.Console.Write(windowPixel);
                System.Console.Write(" ");
                System.Console.WriteLine(windowDestroy);
                int released = System.Australis.Display.Release(); return 10;
            }
            System.Console.WriteLine(
                "Display: window-sized GPU texture passed");
        }
        byte[] firstLayout = new byte[19];
        byte[] secondLayout = new byte[19];
        byte[] beforeFirst = new byte[19];
        byte[] beforeSecond = new byte[19];
        InitLayout(firstLayout, 20, 48, windowWidth, windowHeight);
        InitLayout(secondLayout, width / 3, 72, windowWidth, windowHeight);
        int firstGpu = -1; int secondGpu = -1;
        if (gpuHandle > 0) {
            firstGpu = CreateWindowTexture(firstLayout, firstCells);
            secondGpu = CreateWindowTexture(secondLayout, secondCells);
            if (firstGpu > 0 && secondGpu > 0) {
                System.Console.WriteLine("Display: two GPU-backed window contents ready");
            }
        }

        if (firstGpu > 0 && secondGpu > 0) {

            // Reject ending a frame that is not open.
            int unopened =
                System.Australis.Gpu.EndFrame();

            int begin =
                System.Australis.Gpu.BeginFrame(0x00FF00);

            int duplicate = -1;
            int invalid = -1;
            int firstDraw = -1;
            int secondDraw = -1;
            int finished = -1;

            if (begin == 0) {
                duplicate =
                    System.Australis.Gpu.BeginFrame(0x00FF00);

                invalid =
                    System.Australis.Gpu.DrawWindow(
                        2147483647, 0, 0);

                firstDraw =
                    System.Australis.Gpu.DrawWindow(
                        firstGpu, 12, 16);

                secondDraw =
                    System.Australis.Gpu.DrawWindow(
                        secondGpu, width / 3, 72);

                finished =
                    System.Australis.Gpu.EndFrame();
            }

            if (unopened != -22 ||
                begin != 0 ||
                duplicate != -16 ||
                invalid != -13 ||
                firstDraw != 0 ||
                secondDraw != 0 ||
                finished != 0) {

                System.Console.WriteLine(
                    "Display: GPU frame submission failed");

                int released =
                    System.Australis.Display.Release();

                return 10;
            }

            System.Console.WriteLine(
                "Display: GPU frame submission passed");
        }

        if (firstGpu > 0 && secondGpu > 0) {

            System.Console.WriteLine("GPUDBG: before rounded probe");

            int roundedResult = ProbeGpuRoundedDecorations(
                firstGpu, secondGpu,
                firstLayout, secondLayout,
                width, height);

            System.Console.Write("GPUDBG: rounded returned ");
            System.Console.WriteLine(roundedResult);

            if (roundedResult != 0) {
                System.Console.Write(
                    "Display: GPU rounded decorations failed: ");
                System.Console.WriteLine(roundedResult);

                int released =
                    System.Australis.Display.Release();

                return 10;
            }

            System.Console.WriteLine(
                "Display: GPU rounded decorations passed");
        }

        if (firstGpu > 0 && secondGpu > 0) {

            if (ProbeGpuFrameRects(
                firstGpu, firstLayout,
                width, height) != 0) {

                System.Console.WriteLine(
                    "Display: GPU frame rectangles failed");

                int released =
                    System.Australis.Display.Release();

                return 10;
            }

            System.Console.WriteLine(
                "Display: GPU frame rectangles passed");
        }

        if (firstGpu > 0 && secondGpu > 0) {
            int decorationResult =
                ProbeGpuDecoratedWindows(
                    firstGpu, secondGpu,
                    firstLayout, secondLayout,
                    width, height);

            if (decorationResult != 0) {
                System.Console.Write(
                    "Display: GPU decorated windows failed: ");
                System.Console.WriteLine(decorationResult);

                int released =
                    System.Australis.Display.Release();

                return 10;
            }

            System.Console.WriteLine(
                "Display: GPU decorated windows passed");
        }

        if (firstGpu > 0 && secondGpu > 0) {
            int gpuDesktop = ProbeGpuDesktopComposition(
                firstGpu, secondGpu,
                firstLayout, secondLayout,
                width, height);

            if (gpuDesktop != 0) {
                System.Console.WriteLine(
                    "Display: GPU desktop composition failed");

                int released =
                    System.Australis.Display.Release();

                return 10;
            }

            System.Console.WriteLine("Display: GPU desktop composition passed");
        }

        byte[] retainedWindowIds = new byte[8];
        bool retainedShadowActive = false;
        bool retainedStagingReady = false;

        // Stage retained windows whether their content comes from a GPU
        // texture or from the CPU-backed compact cell buffer.
        int retainedResult = StageRetainedWindows(
            firstLayout, secondLayout,
            firstCells, secondCells,
            firstGpu, secondGpu,
            retainedWindowIds);

        if (retainedResult != 0) {
            System.Console.Write("Display: retained staging failed: ");
            System.Console.WriteLine(retainedResult);
            System.Australis.Display.Release();
            return 10;
        }

        retainedStagingReady = true;
        if (firstGpu > 0 && secondGpu > 0) {
            System.Console.WriteLine("Display: retained GPU window staging passed");
        } else {
            System.Console.WriteLine("Display: retained CPU window staging passed");
        }

        byte[] clip = new byte[8];
        SetClip(clip, 0, 0, width, height);
        int cursorX = width / 2; int cursorY = height / 2;

        System.Console.WriteLine("DBG: resetting instruction budget before software frame");

        int preFrameSleep = System.Australis.Process.Sleep(1);

        System.Console.Write("DBG: pre-frame sleep = ");
        System.Console.WriteLine(preFrameSleep);

        if (preFrameSleep != 0) {
            int released = System.Australis.Display.Release();
            return 6;
        }

        System.Console.WriteLine("DBG 4: starting first frame");

		System.Console.WriteLine("PERF: present START");
        int result = System.Australis.Display.BeginFrame();
		System.Console.WriteLine("PERF: present END");

		System.Console.Write("DBG BeginFrame: ");
		System.Console.WriteLine(result);

		if (result == 0) {
			System.Console.WriteLine("DBG 5: entering Compose");

			result = Compose(
				width, height,
				firstState, firstCells, firstLayout,
				secondState, secondCells, secondLayout,
				clip, 0, 2, firstGpu, secondGpu
			);

			System.Console.Write("DBG Compose: ");
			System.Console.WriteLine(result);
		}

		if (result == 0) {
			System.Console.WriteLine("DBG 6: GPU tile");
			result = ComposeGpuTile(gpuHandle, firstGpu, firstCells);
		}

		if (result == 0 && !hardwareCursor) {
			System.Console.WriteLine("DBG 7: cursor");
			result = Cursor(cursorX, cursorY);
		}

		if (result == 0) {
			System.Console.WriteLine("DBG 8: presenting");
			result = System.Australis.Display.PresentFrame();
		}

		if (result != 0) {
			System.Console.Write("Display startup failed: ");
			System.Console.WriteLine(result);

			int released = System.Australis.Display.Release();
			return 6;
		}
        byte[] frameStats = new byte[20];
        if (System.Australis.Display.Stats(frameStats) != 20 ||
            frameStats[0] != 3 || frameStats[4] != 3 ||
            frameStats[8] != 0 ||
            System.Australis.Display.BeginFrame() != -11) {
            int released = System.Australis.Display.Release(); return 6;
        }
        System.Console.WriteLine("Display: two client windows composed; cursor ready");
        System.Console.WriteLine("Display: cross-window denial and close/reopen verified");
        if (System.Australis.Process.Ready() != 0) {
            int released = System.Australis.Display.Release(); return 7;
        }

        if (firstGpu > 0 && secondGpu > 0) {
            retainedShadowActive = retainedStagingReady;
            System.Console.WriteLine(
                "GPUVIS: starting live GPU visual test");

            int visualResult = ProbeLiveGpuVisual(
                firstGpu, secondGpu,
                firstLayout, secondLayout);

            System.Console.Write("GPUVIS: result = ");
            System.Console.WriteLine(visualResult);

            if (visualResult != 0) {
                int released = System.Australis.Display.Release();
                return 10;
            }
        } else if (retainedStagingReady) {
            // CPU-backed retained composition is not the VirGL visual test.
            retainedShadowActive = true;
            System.Console.WriteLine("Display: retained CPU window composition active");
        }

        byte[] mouse = new byte[3];
        byte[] dirty = new byte[129];
        byte[] pointerEvent = new byte[7];
        byte[] keyEvent = new byte[3];
        int focused = 0;
		int top = 2;
		int captured = 0;
		int buttons = 0;
        int dragKind = 0;
		int dragId = 0;
		int dragEdges = 0;
		int resizeStartMouseX = 0;
		int resizeStartMouseY = 0;
		int resizeStartX = 0;
		int resizeStartY = 0;
		int resizeStartWidth = 0;
		int resizeStartHeight = 0;
        int failure = 0;
        int metricsReported = 0;
        bool gpuLiveEnabled = gpuScanoutSupported;
        int gpuLiveFrames = 0;
        int pacingWaits = 1; // Startup checks that the early frame is deferred.

        while (true) {
            if (initialMode == 0) {
                int packedMode = System.Australis.Display.SetMode(0, 0);
                if (packedMode < 0) {
                    System.Console.WriteLine("Display: mode query failure");
                    failure = 15; break;
                }
                int modeWidth = packedMode % 65536;
                int modeHeight = packedMode / 65536 % 4096;
                if (modeWidth != width || modeHeight != height) {
                    width = modeWidth;
					height = modeHeight;
                    hardwareCursor = packedMode / 268435456 % 2 == 1;
                    int nextWindowWidth = width / 2 - 30;
                    int nextWindowHeight = height / 2;
                    if (width < 320 || height < 240 ||
                        nextWindowWidth < 96 || nextWindowHeight < 80) {
                        failure = 15; break;
                    }
                    InitLayout(firstLayout, 20, 48, nextWindowWidth,
                        nextWindowHeight);
                    InitLayout(secondLayout, width / 3, 72,
                        nextWindowWidth, nextWindowHeight);
                    if (firstGpu > 0) {
                        System.Australis.Gpu.Destroy(firstGpu);
                    }
                    if (secondGpu > 0) {
                        System.Australis.Gpu.Destroy(secondGpu);
                    }
                    firstGpu = -1; secondGpu = -1;
                    if (gpuHandle > 0) {
                        firstGpu = CreateWindowTexture(firstLayout,
                            firstCells);
                        secondGpu = CreateWindowTexture(secondLayout,
                            secondCells);
                    }
                    captured = 0;
                    dragKind = 0; dragId = 0; buttons = 0;
                    cursorX = width / 2; cursorY = height / 2;
                    dirty[0] = 0;
                    Damage(dirty, 0, 0, width, height, width, height);
                    System.Console.Write("Display: mode changed to ");
                    System.Console.Write(width);
                    System.Console.Write("x");
                    System.Console.WriteLine(height);
                }
            }
            int changed = Handle(firstChannel, 1, firstState, firstCells,
                message, reply);
            int other = Handle(secondChannel, 2, secondState, secondCells,
                message, reply);
            if (changed < 0 || other < 0) {
                System.Console.WriteLine("Display: channel failure");
                failure = 8; break;
            }
            if (changed == 1) {
                if (firstState[1] == 1 && gpuHandle > 0) {
                    if (firstGpu > 0) { System.Australis.Gpu.Destroy(firstGpu); }
                    firstGpu = CreateWindowTexture(firstLayout, firstCells);
                }
                Damage(dirty, 0, 0, width, height, width, height);
            } else if (changed == 2) {
                if (firstGpu > 0 && UpdateTextureCell(firstGpu,
                    firstLayout, firstCells, firstState[6],
                    firstState[7]) != 0) {
                    System.Australis.Gpu.Destroy(firstGpu);
                    firstGpu = -1;
                }
                DamageCell(dirty, firstState, firstLayout, width, height);
            }
            if (other == 1) {
                if (secondState[1] == 1 && gpuHandle > 0) {
                    if (secondGpu > 0) {
                        System.Australis.Gpu.Destroy(secondGpu);
                    }
                    secondGpu = CreateWindowTexture(secondLayout,
                        secondCells);
                }
                Damage(dirty, 0, 0, width, height, width, height);
            } else if (other == 2) {
                if (secondGpu > 0 && UpdateTextureCell(secondGpu,
                    secondLayout, secondCells, secondState[6],
                    secondState[7]) != 0) {
                    System.Australis.Gpu.Destroy(secondGpu);
                    secondGpu = -1;
                }
                DamageCell(dirty, secondState, secondLayout, width, height);
            }
            if ((focused == 1 && !Visible(firstState, firstLayout)) ||
                (focused == 2 && !Visible(secondState, secondLayout))) {
                if (focused == 1) {
                    HeaderDamage(dirty, firstLayout, width, height);
                } else { HeaderDamage(dirty, secondLayout, width, height); }
                focused = 0; captured = 0; dragKind = 0; dragId = 0;
                if (Visible(firstState, firstLayout)) { focused = 1; top = 1; }
                if (Visible(secondState, secondLayout)) { focused = 2; top = 2; }
                int capture = 0;
                if (focused > 0) { capture = 1; }
                if (System.Australis.Display.CaptureKeyboard(capture) != 0) {
                    System.Console.WriteLine("Display: keyboard release failure");
                    failure = 9; break;
                }
            }
            CopyLayout(firstLayout, beforeFirst);
            CopyLayout(secondLayout, beforeSecond);
            int beforeTop = top; int beforeFocus = focused;
            int originalX = cursorX; int originalY = cursorY;
            bool oldHardwareCursor = hardwareCursor;
            int moves = 0; int inputFailure = 0;
            while (moves < 16) {
                int mouseResult = System.Australis.Display.PollMouse(mouse);
                if (mouseResult == -1) { break; }
                if (mouseResult != 3) {
                    System.Console.WriteLine("Display: mouse input failure");
                    inputFailure = 1; break;
                }
                hardwareCursor = mouse[0] / 128 % 2 == 1;
                int nextX = cursorX + mouse[1] - 128;
                int nextY = cursorY + mouse[2] - 128;
                if (nextX < 0) { nextX = 0; }
                if (nextY < 0) { nextY = 0; }
                if (nextX > width - 14) { nextX = width - 14; }
                if (nextY > height - 20) { nextY = height - 20; }
                int deltaX = nextX - cursorX;
                int deltaY = nextY - cursorY;
                cursorX = nextX; cursorY = nextY;
                int nextButtons = mouse[0] % 2;
                if (nextButtons == 1 && buttons == 0) {
                    int previousFocus = focused;
                    captured = 0; dragKind = 0; dragId = 0;
                    int menu = MenuHit(cursorX, cursorY, width,
                        firstState, secondState);
                    if (menu > 0) {
                        byte[] selected = firstLayout;
                        if (menu == 2) { selected = secondLayout; }
                        selected[8] = 1;
                        top = menu; focused = menu;
                    } else {
                        int hit = Hit(cursorX, cursorY, firstState,
                            firstLayout, secondState, secondLayout, top);
                        if (cursorY < TopbarHeight()) {
                            byte[] active = firstLayout;
                            byte[] activeState = firstState;
                            if (top == 2) {
                                active = secondLayout;
                                activeState = secondState;
                            }
                            if (Visible(activeState, active) &&
                                active[9] == 1 &&
                                ControlHit(cursorX, cursorY, active) > 0) {
                                hit = top;
                            }
                        }
                        focused = hit;
                        if (hit > 0) {
                            top = hit;
                            byte[] selected = firstLayout;
                            if (hit == 2) { selected = secondLayout; }
                            int control = ControlHit(cursorX, cursorY,
                                selected);
                            if (control == 1) {
                                int pid = firstPid;
                                if (hit == 2) { pid = secondPid; }
                                if (System.Australis.Process.Terminate(pid) != 0) {
                                    inputFailure = 1; break;
                                }
                                selected[8] = 0;
                                if (hit == 1) { firstState[1] = 0; }
                                else { secondState[1] = 0; }
                                focused = 0;
                                if (Visible(firstState, firstLayout)) {
                                    focused = 1; top = 1;
                                }
                                if (Visible(secondState, secondLayout)) {
                                    focused = 2; top = 2;
                                }
                            } else if (control == 2) {
                                selected[8] = 0;
                                focused = 0;
                                if (Visible(firstState, firstLayout)) {
                                    focused = 1; top = 1;
                                }
                                if (Visible(secondState, secondLayout)) {
                                    focused = 2; top = 2;
                                }
                            } else if (control == 3) {
                                ToggleMax(selected, width, height);
							} else if (ResizeEdges(cursorX, cursorY, selected) != 0) {
								dragKind = 2;
								dragId = hit;
								dragEdges = ResizeEdges(
									cursorX, cursorY, selected
								);
								resizeStartMouseX = cursorX;
								resizeStartMouseY = cursorY;
								resizeStartX = Read16(selected, 0);
								resizeStartY = Read16(selected, 2);
								resizeStartWidth = Read16(selected, 4);
								resizeStartHeight = Read16(selected, 6);
							} else if (TitleHit(cursorX, cursorY, selected)) {
								dragKind = 1;
								dragId = hit;
							} else if (ContentHit(cursorX, cursorY, selected)) {
								// Capture pointer input for the clicked application.
								captured = hit;
								// Tell the application that its content was clicked.
								Pointer(captured, 2, cursorX, cursorY,
									firstLayout, secondLayout,
									firstChannel, secondChannel,
									pointerEvent);
							} else if (dragKind == 2) {
 									int dx = cursorX - resizeStartMouseX;
								int dy = cursorY - resizeStartMouseY;

								int leftEdge = resizeStartX;
								int topEdge = resizeStartY;

								int rightEdge = resizeStartX + resizeStartWidth;
								int bottomEdge = resizeStartY + resizeStartHeight;

								// LEFT
								if (dragEdges % 2 == 1) {
									leftEdge = resizeStartX + dx;

									if (leftEdge < 0) {
										leftEdge = 0;
									}

									if (leftEdge > rightEdge - 96) {
										leftEdge = rightEdge - 96;
									}
								}

								// RIGHT
								if (dragEdges / 2 % 2 == 1) {
									rightEdge = resizeStartX + resizeStartWidth + dx;

									if (rightEdge > width) {
										rightEdge = width;
									}

									if (rightEdge < leftEdge + 96) {
										rightEdge = leftEdge + 96;
									}
								}

								// TOP
								if (dragEdges / 4 % 2 == 1) {
									topEdge = resizeStartY + dy;

									if (topEdge < TopbarHeight()) {
										topEdge = TopbarHeight();
									}

									if (topEdge > bottomEdge - 80) {
										topEdge = bottomEdge - 80;
									}
								}

								// BOTTOM
								if (dragEdges / 8 % 2 == 1) {
									bottomEdge =
										resizeStartY + resizeStartHeight + dy;

									if (bottomEdge > height) {
										bottomEdge = height;
									}

									if (bottomEdge < topEdge + 80) {
										bottomEdge = topEdge + 80;
									}
								}

								Write16(selected, 0, leftEdge);
								Write16(selected, 2, topEdge);

								Write16(selected, 4, rightEdge - leftEdge);
								Write16(selected, 6, bottomEdge - topEdge);
							}
                        }
                    }

					if (focused != previousFocus || focused > 0) {
						int capture = 0;
						if (focused > 0) {
							capture = 1;
						}

						int captureResult =
							System.Australis.Display.CaptureKeyboard(capture);

						System.Console.Write("DBG: keyboard focus=");
						System.Console.Write(focused);
						System.Console.Write(" capture=");
						System.Console.Write(capture);
						System.Console.Write(" result=");
						System.Console.WriteLine(captureResult);

						if (captureResult != 0) {
							System.Console.WriteLine(
								"Display: keyboard capture failure");
							inputFailure = 1;
							break;
						}
					}

                } else if (nextButtons == 1 && buttons == 1) {
                    if (dragKind > 0 && dragId > 0 &&
                        (deltaX != 0 || deltaY != 0)) {
                        byte[] selected = firstLayout;
                        if (dragId == 2) { selected = secondLayout; }
						int x = Read16(selected, 0);
						int y = Read16(selected, 2);
						int windowWidth = Read16(selected, 4);
						int windowHeight = Read16(selected, 6);

						if (dragKind == 1) {
							// MOVE WINDOW
							x = x + deltaX;
							y = y + deltaY;

							if (x < 0) {
								x = 0;
							}
							if (y < TopbarHeight()) {
								y = TopbarHeight();
							}
							if (x + windowWidth > width) {
								x = width - windowWidth;
							}
							if (y + windowHeight > height) {
								y = height - windowHeight;
							}

							Write16(selected, 0, x);
							Write16(selected, 2, y);
						}
						else if (dragKind == 2) {
							// RESIZE WINDOW
							int dx = cursorX - resizeStartMouseX;
							int dy = cursorY - resizeStartMouseY;

							// Work from the ORIGINAL boundaries.
							int left = resizeStartX;
							int top = resizeStartY;

							int right = resizeStartX + resizeStartWidth;
							int bottom = resizeStartY + resizeStartHeight;

							// LEFT
							if (dragEdges % 2 == 1) {
								left = resizeStartX + dx;

								if (left < 0) {
									left = 0;
								}
								if (left > right - 96) {
									left = right - 96;
								}
							}

							// RIGHT
							if (dragEdges / 2 % 2 == 1) {
								right = resizeStartX + resizeStartWidth + dx;

								if (right > width) {
									right = width;
								}
								if (right < left + 96) {
									right = left + 96;
								}
							}

							// TOP
							if (dragEdges / 4 % 2 == 1) {
								top = resizeStartY + dy;

								if (top < TopbarHeight()) {
									top = TopbarHeight();
								}
								if (top > bottom - 80) {
									top = bottom - 80;
								}
							}

							// BOTTOM
							if (dragEdges / 8 % 2 == 1) {
								bottom = resizeStartY + resizeStartHeight + dy;

								if (bottom > height) {
									bottom = height;
								}
								if (bottom < top + 80) {
									bottom = top + 80;
								}
							}

							// Important: update BOTH position and dimensions.
							Write16(selected, 0, left);
							Write16(selected, 2, top);
							Write16(selected, 4, right - left);
							Write16(selected, 6, bottom - top);
						}
                    } else if (captured > 0 &&
                        (deltaX != 0 || deltaY != 0)) {
                        Pointer(captured, 1, cursorX, cursorY,
                            firstLayout, secondLayout, firstChannel,
                            secondChannel, pointerEvent);
                    }
                } else if (nextButtons == 0 && buttons == 1) {
                    if (captured > 0) {
                        Pointer(captured, 3, cursorX, cursorY,
                            firstLayout, secondLayout, firstChannel,
                            secondChannel, pointerEvent);
                    }
                    captured = 0; dragKind = 0; dragId = 0;
                }
                buttons = nextButtons;
                moves = moves + 1;
            }
            if (inputFailure != 0) { failure = 9; break; }
            int hoverHit = Hit(cursorX, cursorY, firstState,
                firstLayout, secondState, secondLayout, top);
            if (cursorY < TopbarHeight()) {
                byte[] active = firstLayout;
                byte[] activeState = firstState;
                if (top == 2) {
                    active = secondLayout; activeState = secondState;
                }
                if (Visible(activeState, active) && active[9] == 1 &&
                    ControlHit(cursorX, cursorY, active) > 0) {
                    hoverHit = top;
                }
            }
            firstLayout[18] = 0; secondLayout[18] = 0;
            if (hoverHit == 1) {
                firstLayout[18] = (byte)ControlHit(cursorX, cursorY,
                    firstLayout);
            }
            if (hoverHit == 2) {
                secondLayout[18] = (byte)ControlHit(cursorX, cursorY,
                    secondLayout);
            }
            if (LayoutChanged(beforeFirst, firstLayout)) {
                if (Read16(beforeFirst, 4) != Read16(firstLayout, 4) ||
                    Read16(beforeFirst, 6) != Read16(firstLayout, 6) ||
                    beforeFirst[9] != firstLayout[9]) {
                    if (firstGpu > 0) {
                        System.Australis.Gpu.Destroy(firstGpu);
                    }
                    firstGpu = -1;
                    if (gpuHandle > 0) {
                        firstGpu = CreateWindowTexture(firstLayout,
                            firstCells);
                    }
                }
                DamageTransition(dirty, beforeFirst, firstLayout,
                    width, height);
                if (beforeFirst[9] != firstLayout[9]) {
                    Damage(dirty, 0, 0, width, 32, width, height);
                }
            }
            if (LayoutChanged(beforeSecond, secondLayout)) {
                if (Read16(beforeSecond, 4) != Read16(secondLayout, 4) ||
                    Read16(beforeSecond, 6) != Read16(secondLayout, 6) ||
                    beforeSecond[9] != secondLayout[9]) {
                    if (secondGpu > 0) {
                        System.Australis.Gpu.Destroy(secondGpu);
                    }
                    secondGpu = -1;
                    if (gpuHandle > 0) {
                        secondGpu = CreateWindowTexture(secondLayout,
                            secondCells);
                    }
                }
                DamageTransition(dirty, beforeSecond, secondLayout, width, height);
                if (beforeSecond[9] != secondLayout[9]) {
                    Damage(dirty, 0, 0, width, 32, width, height);
                }
            }
			if (beforeTop != top) {
				DamageOverlap(dirty, firstLayout, secondLayout, width, height);
				Damage(dirty, 0, 0, width, 32, width, height);
			}
            if (beforeFocus != focused) {
                if (beforeFocus == 1) {
                    HeaderDamage(dirty, beforeFirst, width, height);
                }
                if (beforeFocus == 2) {
                    HeaderDamage(dirty, beforeSecond, width, height);
                }
                if (focused == 1) {
                    HeaderDamage(dirty, firstLayout, width, height);
                }
                if (focused == 2) {
                    HeaderDamage(dirty, secondLayout, width, height);
                }
            }
			if (beforeFirst[18] != firstLayout[18]) {
				ControlDamage(dirty, beforeFirst, beforeFirst[18], width, height);
				ControlDamage(dirty, firstLayout, firstLayout[18], width, height);
			}

			if (beforeSecond[18] != secondLayout[18]) {
				ControlDamage(dirty, beforeSecond, beforeSecond[18], width, height);
				ControlDamage(dirty, secondLayout, secondLayout[18], width, height);
			}
            if (cursorX != originalX || cursorY != originalY ||
                hardwareCursor != oldHardwareCursor) {
                if (!oldHardwareCursor) {
                    Damage(dirty, originalX, originalY, 14, 20,
                        width, height);
                }
                if (!hardwareCursor) {
                    Damage(dirty, cursorX, cursorY, 14, 20,
                        width, height);
                }
            }

			if (retainedShadowActive) {

				// These operations do not have matching retained APIs yet.
				bool unsupported =
					!Visible(firstState, firstLayout) ||
					!Visible(secondState, secondLayout) ||
					firstLayout[9] == 1 ||
					secondLayout[9] == 1 ||
					Read16(beforeFirst, 4) != Read16(firstLayout, 4) ||
					Read16(beforeFirst, 6) != Read16(firstLayout, 6) ||
					Read16(beforeSecond, 4) != Read16(secondLayout, 4) ||
					Read16(beforeSecond, 6) != Read16(secondLayout, 6);

				if (unsupported) {
					retainedShadowActive = false;
					System.Console.WriteLine("Display: retained shadow suspended");
				} else {
					int status = SyncRetainedWindow(retainedWindowIds, 0, beforeFirst, firstLayout, firstCells, firstGpu, changed == 1 || changed == 2);
					if (status == 0) {
						status = SyncRetainedWindow(retainedWindowIds, 4, beforeSecond, secondLayout, secondCells, secondGpu, other == 1 || other == 2);
					}

					// Keep retained stacking order aligned with the desktop.
					if (status == 0 && beforeTop != top) {
						int selectedId = RetainedWindowId(
							retainedWindowIds, 0);

						if (top == 2) {
							selectedId = RetainedWindowId(
								retainedWindowIds, 4);
						}

						status = System.Australis.Display.RetainedFocus(
							selectedId);
					}

					// Hover follows the existing desktop pointer.
					if (status == 0 &&
						(cursorX != originalX || cursorY != originalY)) {

						status = System.Australis.Display.RetainedHover(
							cursorX, cursorY);
					}

					if (status != 0) {
						retainedShadowActive = false;
						System.Console.Write("Display: retained sync stopped: ");
						System.Console.WriteLine(status);
					}
				}
			}

            if (dirty[0] > 0) {
                int gpuFrameResult = 0;
				// Try retained rendering before the old GPU renderer.
				if (retainedShadowActive) {
					int retainedResult = FlushRetained(dirty, width, height, cursorX, cursorY, hardwareCursor);
					if (retainedResult >= 0) {
						// Retained frame already presented.
						gpuFrameResult = 1;
						pacingWaits = pacingWaits + retainedResult;
					} else {
						System.Console.Write("Display: retained frame failed: ");
						System.Console.WriteLine(retainedResult);
						// Stop using the shadow until it is rebuilt.
						retainedShadowActive = false;

						// A failed retained frame may be partially composed.
						// Force the existing fallback to repaint everything.
						dirty[0] = 0;
						Damage(dirty, 0, 0, width, height, width, height);

						System.Console.WriteLine("Display: retained fallback");
					}
				}

				// Only render the legacy GPU frame if retained did not
				// successfully present the frame.
				if (gpuFrameResult == 0 && gpuLiveEnabled) {
					gpuFrameResult = TryGpuLiveFrame(width, height, firstState, firstLayout, firstGpu, secondState, secondLayout, secondGpu, focused, top);
					if (gpuFrameResult < 0) {
						gpuLiveEnabled = false;
						System.Console.WriteLine("Display: GPU composition failed; software fallback");
					}
				}

                if (gpuFrameResult == 1) {
                    // GPU has presented the complete frame.
                    dirty[0] = 0;
                    gpuLiveFrames = gpuLiveFrames + 1;

                    if (gpuLiveFrames == 1) {
                        System.Console.WriteLine(
                            "Display: live GPU composition active");
                    }
                } else {
                    // Restore 2D scanout before software fallback.
					if (gpuScanoutSupported && System.Australis.Gpu.RestoreFrame() != 0) {
						System.Console.WriteLine("Display: GPU scanout restoration failed");
						failure = 10;
						break;
					}

                    // Original software rendering path.
                    int waitCount = Flush(dirty, clip, width, height,
                        firstState, firstCells, firstLayout, secondState,
                        secondCells, secondLayout, focused, top,
                        cursorX, cursorY, hardwareCursor,
                        firstGpu, secondGpu);

                    if (waitCount < 0) {
                        System.Console.WriteLine("Display: redraw failure");
                        failure = 10;
                        break;
                    }

                    pacingWaits = pacingWaits + waitCount;

                    // Existing software frame statistics.
                    if (metricsReported == 0) {
                        if (System.Australis.Display.Stats(frameStats) != 20) {
                            System.Console.WriteLine("Display: frame stats failure");
                            failure = 14;
                            break;
                        }

                        int submitted = Read16(frameStats, 0) +
                            Read16(frameStats, 2) * 65536;
                        int presented = Read16(frameStats, 4) +
                            Read16(frameStats, 6) * 65536;
                        int dropped = Read16(frameStats, 8) +
                            Read16(frameStats, 10) * 65536;

						if (submitted != presented || dropped != 0) {
							System.Console.Write("Display: submitted=");
							System.Console.WriteLine(submitted);
							System.Console.Write("Display: presented=");
							System.Console.WriteLine(presented);
							System.Console.Write("Display: dropped=");
							System.Console.WriteLine(dropped);

							System.Console.WriteLine("Display: frame count failure");
							failure = 14;
							break;
						}

                        if (presented >= 2) {
                            int lastMicros = Read16(frameStats, 12) +
                                Read16(frameStats, 14) * 65536;
                            int maxMicros = Read16(frameStats, 16) +
                                Read16(frameStats, 18) * 65536;

                            System.Console.Write("Display: paced frames=");
                            System.Console.Write(presented);
                            System.Console.Write(" last_us=");
                            System.Console.Write(lastMicros);
                            System.Console.Write(" max_us=");
                            System.Console.Write(maxMicros);
                            System.Console.Write(" waits=");
                            System.Console.WriteLine(pacingWaits);

                            metricsReported = 1;
                        }
                    }
                }
            }

            if (focused > 0) {
                int keys = 0;
                while (keys < 8) {
					int key = System.Australis.Display.PollKey();

					if (key >= 0) {
						System.Console.Write("DBG: Display received key=");
						System.Console.WriteLine(key);
					}
                    if (key == -1) { break; }
                    if (key < -1) {
                        System.Console.WriteLine("Display: keyboard input failure");
                        failure = 11; break;
                    }
                    if (key <= 255) {
                        if (initialMode == 0 && key == 109) {
                            int nextWidth = 1024;
                            int nextHeight = 768;
                            if (width == 1024 && height == 768) {
                                nextWidth = 1280; nextHeight = 800;
                            }
							int modeResult = System.Australis.Display.SetMode(nextWidth, nextHeight);

							if (modeResult != 0) {
								System.Console.WriteLine("Display: mode switch failure");
								failure = 15;
							} else {
								// SetMode invalidates the kernel's retained renderer.
								// Stop using the old retained windows immediately.
								retainedShadowActive = false;
								retainedStagingReady = false;
							}
							break;
                        }
						bool gpuScanoutSupported = initialMode == 0;
                        keyEvent[0] = 5; keyEvent[1] = (byte)focused;
                        keyEvent[2] = (byte)key;
                        int channel = firstChannel;
                        if (focused == 2) { channel = secondChannel; }
                        int sent = System.Australis.Channel.Send(channel, 2,
                            keyEvent);
                    }
                    keys = keys + 1;
                }
            }
            if (failure != 0) { break; }
            int sleepMilliseconds = 10;
            if (moves > 0) { sleepMilliseconds = 2; }
            int slept = System.Australis.Process.Sleep(sleepMilliseconds);
            if (slept != 0) {
                System.Console.WriteLine("Display: sleep failure");
                failure = 12; break;
            }
        }
		int released = System.Australis.Display.Release();
		if (released != 0 && failure == 0) { failure = 13; }

		System.Console.Write("Display: exit code = ");
		System.Console.WriteLine(failure);

		return failure;
    }

    private static bool NearGpuRgb(int actual, int expected) {
        if (actual < 0 || expected < 0) {
            return false;
        }

        int r = actual / 65536 % 256 -
            expected / 65536 % 256;
        int g = actual / 256 % 256 -
            expected / 256 % 256;
        int b = actual % 256 - expected % 256;

        if (r < 0) { r = 0 - r; }
        if (g < 0) { g = 0 - g; }
        if (b < 0) { b = 0 - b; }

        return r <= 8 && g <= 8 && b <= 8;
    }

    private static int ProbeGpuFrameRects(int handle, byte[] layout, int width, int height) {

        int x = Read16(layout, 0) + 8;
        int y = ContentTop(layout);

        if (handle < 1 ||
            x < 0 || y < 0 ||
            x + 32 > width ||
            y + 32 > height) {
            return -22;
        }

        // No active GPU frame.
        if (System.Australis.Gpu.FillFrameRect(
            2, 2, 12, 12, 0x4488CC) != -22) {
            return -5;
        }

        if (System.Australis.Gpu.BeginFrame(
            0x26384F) != 0) {
            return -5;
        }

        // Invalid rectangle must not corrupt the frame.
        int invalid =
            System.Australis.Gpu.FillFrameRect(
                width - 4, 0, 8, 8, 0xFFFFFF);

        // Background decoration.
        int background =
            System.Australis.Gpu.FillFrameRect(
                2, 2, 12, 12, 0x4488CC);

        // Actual application window texture.
        int window =
            System.Australis.Gpu.DrawWindow(
                handle, x, y);

        // Foreground decoration above the window.
        int foreground =
            System.Australis.Gpu.FillFrameRect(
                x + 4, y + 4, 8, 8, 0xAA4400);

        int end =
            System.Australis.Gpu.EndFrame();

        if (invalid != -22 ||
            background != 0 ||
            window != 0 ||
            foreground != 0 ||
            end != 0) {
            return -5;
        }

        int originalPixel =
            System.Australis.Gpu.ReadPixel(handle, 20, 20);

        if (!NearGpuRgb(
                System.Australis.Gpu.FramePixel(1, 1),
                0x26384F) ||
            !NearGpuRgb(
                System.Australis.Gpu.FramePixel(5, 5),
                0x4488CC) ||
            !NearGpuRgb(
                System.Australis.Gpu.FramePixel(
                    x + 6, y + 6),
                0xAA4400) ||
            !NearGpuRgb(
                System.Australis.Gpu.FramePixel(
                    x + 20, y + 20),
                originalPixel)) {
            return -5;
        }

        return 0;
    }

    private static int ProbeGpuDesktopComposition(int firstGpu, int secondGpu, byte[] firstLayout, byte[] secondLayout, int width, int height) {

        // Actual window-content positions on the desktop.
        int ax = Read16(firstLayout, 0) + 8;
        int ay = ContentTop(firstLayout);
        int bx = Read16(secondLayout, 0) + 8;
        int by = ContentTop(secondLayout);

        int aw = ContentWidth(firstLayout);
        int ah = ContentHeight(firstLayout);
        int bw = ContentWidth(secondLayout);
        int bh = ContentHeight(secondLayout);

        // A pixel inside both windows.
        int overlapX = bx + 8;
        int overlapY = by + 8;

        if (firstGpu < 1 || secondGpu < 1 ||
            aw < 16 || ah < 16 ||
            bw < 16 || bh < 16 ||
            ax < 0 || ay < 0 ||
            bx < 0 || by < 0 ||
            ax + aw > width || ay + ah > height ||
            bx + bw > width || by + bh > height ||
            overlapX < ax || overlapX >= ax + aw ||
            overlapY < ay || overlapY >= ay + ah) {
            return -22;
        }

        int firstColor =
            System.Australis.Gpu.ReadPixel(firstGpu, 8, 8);

        int secondColor =
            System.Australis.Gpu.ReadPixel(
                secondGpu, bw - 8, 8);

        int overlapFirst =
            System.Australis.Gpu.ReadPixel(
                firstGpu, overlapX - ax, overlapY - ay);

        int overlapSecond =
            System.Australis.Gpu.ReadPixel(secondGpu, 8, 8);

        if (firstColor < 0 || secondColor < 0 ||
            overlapFirst < 0 || overlapSecond < 0 ||
            NearGpuRgb(overlapFirst, overlapSecond)) {
            return -5;
        }

        // Frame A: first window behind second window.
        if (System.Australis.Gpu.BeginFrame(0x00FF00) != 0 ||
            System.Australis.Gpu.DrawWindow(
                firstGpu, ax, ay) != 0 ||
            System.Australis.Gpu.DrawWindow(
                secondGpu, bx, by) != 0 ||
            System.Australis.Gpu.EndFrame() != 0) {
            return -5;
        }

        if (!NearGpuRgb(
                System.Australis.Gpu.FramePixel(2, 2),
                0x00FF00) ||
            !NearGpuRgb(
                System.Australis.Gpu.FramePixel(ax + 8, ay + 8),
                firstColor) ||
            !NearGpuRgb(
                System.Australis.Gpu.FramePixel(
                    bx + bw - 8, by + 8),
                secondColor) ||
            !NearGpuRgb(
                System.Australis.Gpu.FramePixel(
                    overlapX, overlapY),
                overlapSecond)) {
            return -5;
        }

        // Frame B: reverse the stacking order.
        if (System.Australis.Gpu.BeginFrame(0x00FF00) != 0 ||
            System.Australis.Gpu.DrawWindow(
                secondGpu, bx, by) != 0 ||
            System.Australis.Gpu.DrawWindow(
                firstGpu, ax, ay) != 0 ||
            System.Australis.Gpu.EndFrame() != 0) {
            return -5;
        }

        // The overlapping pixel must now belong to A.
        if (!NearGpuRgb(
            System.Australis.Gpu.FramePixel(
                overlapX, overlapY),
            overlapFirst)) {
            return -5;
        }

        return 0;
    }

    private static int ProbeGpuBatchColours() {
        // First test: one rectangle, flushed at EndFrame.
        if (System.Australis.Gpu.BeginFrame(0x26384F) != 0) {
            return -71;
        }

        int singleDraw = System.Australis.Gpu.FillFrameRect(
            32, 48, 8, 8, 0xE5E8ED);

        int singleEnd = System.Australis.Gpu.EndFrame();

        if (singleDraw != 0 || singleEnd != 0) {
            return -72;
        }

        int single = System.Australis.Gpu.FramePixel(32, 48);

        System.Console.Write("GPUDBG: single titlebar = ");
        System.Console.WriteLine(single);

        if (!NearGpuRgb(single, 0xE5E8ED)) {
            return -73;
        }

        // Second test: four rectangles in one batch.
        if (System.Australis.Gpu.BeginFrame(0x26384F) != 0) {
            return -74;
        }

        int a = System.Australis.Gpu.FillFrameRect(
            32, 48, 8, 8, 0xE5E8ED);
        int b = System.Australis.Gpu.FillFrameRect(
            48, 48, 8, 8, 0xFF5F57);
        int c = System.Australis.Gpu.FillFrameRect(
            64, 48, 8, 8, 0xFEBC2E);
        int d = System.Australis.Gpu.FillFrameRect(
            80, 48, 8, 8, 0x28C840);

        int end = System.Australis.Gpu.EndFrame();

        if (a != 0 || b != 0 || c != 0 ||
            d != 0 || end != 0) {
            return -75;
        }

        int pa = System.Australis.Gpu.FramePixel(32, 48);
        int pb = System.Australis.Gpu.FramePixel(48, 48);
        int pc = System.Australis.Gpu.FramePixel(64, 48);
        int pd = System.Australis.Gpu.FramePixel(80, 48);

        System.Console.Write("GPUDBG: batch titlebar = ");
        System.Console.WriteLine(pa);
        System.Console.Write("GPUDBG: batch close = ");
        System.Console.WriteLine(pb);
        System.Console.Write("GPUDBG: batch minimise = ");
        System.Console.WriteLine(pc);
        System.Console.Write("GPUDBG: batch maximise = ");
        System.Console.WriteLine(pd);

        if (!NearGpuRgb(pa, 0xE5E8ED) ||
            !NearGpuRgb(pb, 0xFF5F57) ||
            !NearGpuRgb(pc, 0xFEBC2E) ||
            !NearGpuRgb(pd, 0x28C840)) {
            return -76;
        }

        return 0;
    }

    private static int TryGpuLiveFrame(int width, int height, byte[] firstState, byte[] firstLayout, int firstGpu, byte[] secondState, byte[] secondLayout, int secondGpu, int focused, int top) {

        // First milestone: two normal, GPU-backed windows.
        // Unsupported states use the software renderer.
        if (firstGpu < 1 || secondGpu < 1 ||
            firstLayout[9] == 1 || secondLayout[9] == 1) {
            return 0;
        }

        // Single-render-target implementation:
        // restore 2D before drawing into the GPU target again.
        if (System.Australis.Gpu.RestoreFrame() != 0) {
            return -1;
        }

        if (System.Australis.Process.Sleep(1) != 0) {
            return -1;
        }

        if (System.Australis.Gpu.BeginFrame(0x26384F) != 0) {
            return -1;
        }

        int result = 0;

        if (top == 1) {
            // Window A is above window B.
            if (Visible(secondState, secondLayout)) {
                result = GpuDrawRoundedWindow(
                    secondLayout, secondGpu, focused == 2);
            }

            if (result != 0) { return -1; }

            if (System.Australis.Process.Sleep(1) != 0) {
                return -1;
            }

            if (Visible(firstState, firstLayout)) {
                result = GpuDrawRoundedWindow(
                    firstLayout, firstGpu, focused == 1);
            }
        } else {
            // Window B is above window A.
            if (Visible(firstState, firstLayout)) {
                result = GpuDrawRoundedWindow(
                    firstLayout, firstGpu, focused == 1);
            }

            if (result != 0) { return -1; }

            if (System.Australis.Process.Sleep(1) != 0) {
                return -1;
            }

            if (Visible(secondState, secondLayout)) {
                result = GpuDrawRoundedWindow(
                    secondLayout, secondGpu, focused == 2);
            }
        }

        if (result != 0) { return -1; }

        // Match the normal desktop topbar.
        if (System.Australis.Gpu.FillFrameRect(
            0, 0, width, TopbarHeight(), 0x111820) != 0) {
            return -1;
        }

        if (System.Australis.Process.Sleep(1) != 0) {
            return -1;
        }

        if (System.Australis.Gpu.EndFrame() != 0) {
            return -1;
        }

        if (System.Australis.Gpu.PresentFrame() != 0) {
            return -1;
        }

        return 1;
    }

    private static int ProbeGpuRoundedDecorations(int firstGpu, int secondGpu, byte[] firstLayout, byte[] secondLayout, int width, int height) {

        System.Console.WriteLine("GPUDBG: rounded STEP 1 - entered");

        if (firstGpu < 1 || secondGpu < 1) {
            return -22;
        }

        if (firstLayout.Length < 19 || secondLayout.Length < 19) {
            return -22;
        }

        System.Console.WriteLine("GPUDBG: rounded STEP 2 - layouts valid");

        if (firstLayout[9] != 0 || secondLayout[9] != 0) {
            return -22;
        }

        int ax = Read16(firstLayout, 0);
        int ay = Read16(firstLayout, 2);
        int bx = Read16(secondLayout, 0);
        int by = Read16(secondLayout, 2);
        int bw = Read16(secondLayout, 4);

        System.Console.WriteLine("GPUDBG: rounded STEP 3 - coordinates read");

        int topA = ContentTop(firstLayout);
        int topB = ContentTop(secondLayout);

        System.Console.WriteLine("GPUDBG: rounded STEP 4 - content tops");

        int overlapX = bx + 16;
        int overlapY = topB + 16;

        int firstLocalX = overlapX - ax - 8;
        int firstLocalY = overlapY - topA;

        System.Console.WriteLine("GPUDBG: rounded STEP 5 - overlap calculated");

        int contentWidthA = ContentWidth(firstLayout);
        int contentHeightA = ContentHeight(firstLayout);

        if (firstLocalX < 0 || firstLocalY < 0 ||
            firstLocalX >= contentWidthA ||
            firstLocalY >= contentHeightA) {
            return -22;
        }

        System.Console.WriteLine("GPUDBG: rounded STEP 6 - geometry valid");


        System.Console.WriteLine("GPUDBG: rounded STEP 7 - reading texture A");

        int colorA = System.Australis.Gpu.ReadPixel(firstGpu, firstLocalX, firstLocalY);

        System.Console.WriteLine("GPUDBG: rounded STEP 8 - texture A returned");

        System.Console.Write("GPUDBG: colorA = ");
        System.Console.WriteLine(colorA);

        if (colorA < 0) {
            return -61;
        }

        System.Console.WriteLine("GPUDBG: rounded STEP 9 - reading texture B");

        int colorB = System.Australis.Gpu.ReadPixel(secondGpu, 16, 16);

        System.Console.WriteLine("GPUDBG: rounded STEP 10 - texture B returned");

        System.Console.Write("GPUDBG: colorB = ");
        System.Console.WriteLine(colorB);

        if (colorB < 0) {
            return -62;
        }

        System.Console.WriteLine("GPUDBG: rounded STEP 11 - comparing colours");

        if (NearGpuRgb(colorA, colorB)) {
            return -63;
        }

        System.Console.WriteLine("GPUDBG: rounded STEP 12 - source pixels valid");

        // B above A.
        if (System.Australis.Gpu.BeginFrame(0x26384F) != 0 ||
            GpuDrawRoundedWindow(firstLayout, firstGpu, false) != 0 ||
            GpuDrawRoundedWindow(secondLayout, secondGpu, true) != 0 ||
            System.Australis.Gpu.EndFrame() != 0) {
            return -52;
        }

        int size = TitlebarControlSize();
        int controlAY = ControlY(ay, TitlebarHeight());
        int controlBY = ControlY(by, TitlebarHeight());


        if (!CheckRoundedPixel("A top-left rounded corner", ax, ay, 0x26384F) ||
            !CheckRoundedPixel("B top-right rounded corner", bx + bw - 1, by, 0x26384F) ||
            !CheckRoundedPixel("A titlebar", ax + WindowRadius(), ay, UnfocusedTitlebar()) ||
            !CheckRoundedPixel("A close control", ControlX(ax, 0) + size / 2, controlAY + size / 2, 0xFF5F57) ||
            !CheckRoundedPixel("B close control", ControlX(bx, 0) + size / 2, controlBY + size / 2, 0xFF5F57) ||
            !CheckRoundedPixel("B minimise control", ControlX(bx, 1) + size / 2, controlBY + size / 2, 0xFEBC2E) ||
            !CheckRoundedPixel("B maximise control", ControlX(bx, 2) + size / 2, controlBY + size / 2, 0x28C840) ||
            !CheckRoundedPixel("B window content overlap", overlapX, overlapY, colorB)) {

            return -53;
        }

        System.Console.WriteLine("GPUDBG: STEP 13");

        // Reverse stacking: A above B.

        System.Console.WriteLine("GPUDBG: frame 2 starting");

        System.Console.WriteLine("GPUDBG: pausing before frame 2");

        int pauseResult = System.Australis.Process.Sleep(1);

        System.Console.Write("GPUDBG: pause result = ");
        System.Console.WriteLine(pauseResult);

        if (pauseResult != 0) {
            return -540;
        }

        // Existing frame 2 code continues here.
        System.Console.WriteLine("GPUDBG: frame 2 starting");

        int begin2 = System.Australis.Gpu.BeginFrame(0x26384F);
        System.Console.Write("GPUDBG: frame 2 BeginFrame = ");
        System.Console.WriteLine(begin2);
        if (begin2 != 0) {
            return -541;
        }

        System.Console.WriteLine("GPUDBG: frame 2 drawing B");
        int drawB2 = GpuDrawRoundedWindow(secondLayout, secondGpu, false);

        System.Console.Write("GPUDBG: frame 2 DrawB = ");
        System.Console.WriteLine(drawB2);
        if (drawB2 != 0) {
            return -542;
        }

        System.Console.WriteLine("GPUDBG: frame 2 drawing A");
        int drawA2 = GpuDrawRoundedWindow(
            firstLayout, firstGpu, true);

        System.Console.Write("GPUDBG: frame 2 DrawA = ");
        System.Console.WriteLine(drawA2);
        if (drawA2 != 0) {
            return -543;
        }

        System.Console.WriteLine("GPUDBG: frame 2 ending");
        int end2 = System.Australis.Gpu.EndFrame();

        System.Console.Write("GPUDBG: frame 2 EndFrame = ");
        System.Console.WriteLine(end2);
        if (end2 != 0) {
            return -544;
        }

        System.Console.WriteLine("GPUDBG: rounded frame 2 rendered");


        System.Console.WriteLine("GPUDBG: STEP 14");

        if (!NearGpuRgb(
            System.Australis.Gpu.FramePixel(overlapX, overlapY), colorA)) {
            return -55;
        }

        System.Console.WriteLine("GPUDBG: STEP 15");

        System.Console.WriteLine("GPUDBG: selecting live GPU scanout");

        int liveResult = System.Australis.Gpu.PresentFrame();

        System.Console.Write("GPUDBG: live presentation = ");
        System.Console.WriteLine(liveResult);

        if (liveResult != 0) {
            return -81;
        }

        System.Console.WriteLine("GPUDBG: restoring software scanout");

        int restoreResult = System.Australis.Gpu.RestoreFrame();

        System.Console.Write("GPUDBG: scanout restore = ");
        System.Console.WriteLine(restoreResult);

        if (restoreResult != 0) {
            return -82;
        }

        System.Console.WriteLine("Display: live GPU presentation round-trip passed");

        return 0;
    }

    private static bool CheckRoundedPixel(string name, int x, int y, int expected) {

        int actual =
            System.Australis.Gpu.FramePixel(x, y);

        if (NearGpuRgb(actual, expected)) {
            return true;
        }

        System.Console.Write("GPUDBG: FAILED ");
        System.Console.WriteLine(name);

        System.Console.Write("GPUDBG: position ");
        System.Console.Write(x);
        System.Console.Write(", ");
        System.Console.WriteLine(y);

        System.Console.Write("GPUDBG: expected ");
        System.Console.WriteLine(expected);

        System.Console.Write("GPUDBG: actual ");
        System.Console.WriteLine(actual);

        return false;
    }

    private static bool CheckGpuProbePixel(string label, int x, int y, int expected) {

        int actual =
            System.Australis.Gpu.FramePixel(x, y);

        if (NearGpuRgb(actual, expected)) {
            return true;
        }

        System.Console.Write("GPUDBG: pixel failed: ");
        System.Console.WriteLine(label);

        System.Console.Write(" expected RGB: ");
        System.Console.WriteLine(expected);

        System.Console.Write(" actual RGB: ");
        System.Console.WriteLine(actual);

        System.Console.Write(" coordinates: ");
        System.Console.Write(x);
        System.Console.Write(", ");
        System.Console.WriteLine(y);

        return false;
    }

    private static int ProbeLiveGpuVisual(int firstGpu, int secondGpu, byte[] firstLayout, byte[] secondLayout) {

        if (firstGpu < 1 || secondGpu < 1) {
            return -95;
        }

        // Reset the AUEX instruction watchdog.
        if (System.Australis.Process.Sleep(1) != 0) {
            return -1;
        }

        int result =
            System.Australis.Gpu.BeginFrame(0x26384F);

        if (result != 0) {
            return -2;
        }

        // A below B.
        result = GpuDrawRoundedWindow(
            firstLayout, firstGpu, false);

        if (result != 0) {
            return -3;
        }

        if (System.Australis.Process.Sleep(1) != 0) {
            return -4;
        }

        result = GpuDrawRoundedWindow(
            secondLayout, secondGpu, true);

        if (result != 0) {
            return -5;
        }

        if (System.Australis.Process.Sleep(1) != 0) {
            return -6;
        }

        result = System.Australis.Gpu.EndFrame();

        if (result != 0) {
            return -7;
        }

        result = System.Australis.Gpu.PresentFrame();

        if (result != 0) {
            System.Console.WriteLine("GPUVIS: PRESENT FAILED");
            return -8;
        }

        // Screenshot synchronisation marker.
        System.Console.WriteLine("GPUVIS: PRESENTED");

        // Safe here because Display has announced readiness.
        int hold = System.Australis.Process.Sleep(3000);

        // Always attempt restoration after presentation.
        int restored = System.Australis.Gpu.RestoreFrame();

        if (restored != 0) {
            System.Console.WriteLine("GPUVIS: RESTORE FAILED");
            return -9;
        }

        System.Console.WriteLine("GPUVIS: RESTORED");

        if (hold != 0) {
            return -10;
        }

        return 0;
    }

}
