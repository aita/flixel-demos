package;

import openfl.geom.Point;
import openfl.geom.Rectangle;
import flixel.addons.util.FlxSimplex;
import flixel.util.FlxColor;
import flixel.FlxSprite;

class SimplexHelper
{
	// where to begin sampling noise in X
	public var x:Int;
	// where to begin sampling noise in Y
	public var y:Int;
	// how zoomed in or out the noise is
	public var scale:Float;
	// how much multiple octaves influence the final output (something like resolution)
	public var persistence:Float;
	// how many times the noise gets layered over itself (more octaves require more time to process)
	public var octaves:Int;
	// if the noise is tiled or not (tiled noise takes longer to process)
	public var tile:Bool;
	// a random number that changes the output, even if all other parameters are the same
	public var seed:Int;

	// how much the display scrolls by per frame
	public var scrollAmount:Int;
	// the width and height of each tile, if tiling is turned on
	public var tileSize:Int;

	// a reference back to the main sprite that we're drawing onto
	var canvasRef:FlxSprite;

	var srcRect:Rectangle;
	var dstPt:Point;

	public function new(canvasRef:FlxSprite)
	{
		// some default parameters that look nice
		x = 0;
		y = 0;
		scale = 0.007;
		persistence = .75;
		octaves = 4;
		tile = false;
		seed = 0;

		scrollAmount = 5;
		tileSize = 200;

		this.canvasRef = canvasRef;

		srcRect = new Rectangle();
		dstPt = new Point();

		regenSimplex();
	}

	/**
	 * Regenerates every pixel of the canvas with a noise value.
	 */
	public function regenSimplex():Void
	{
		if (tile)
		{
			// since tiled noise repeats, we only need to generate noise for one tile
			for (i in 0...tileSize)
			{
				for (j in 0...tileSize)
				{
					setNoiseValue(i, j);
				}
			}

			// then we use copyPixels to draw the other tiles, since we know what they look like already
			var numX = Math.ceil(canvasRef.frameWidth / tileSize);
			var numY = Math.ceil(canvasRef.frameHeight / tileSize);

			srcRect.setTo(0, 0, tileSize, tileSize);
			dstPt.setTo(0, 0);

			for (i in 0...numX)
			{
				dstPt.x = i * tileSize;

				for (j in 0...numY)
				{
					if (i == 0 && j == 0)
						continue;

					dstPt.y = j * tileSize;

					canvasRef.pixels.copyPixels(canvasRef.pixels, srcRect, dstPt, null, null, false);
				}
			}
		}
		else
		{
			// regen noise for every pixel in the canvas
			for (i in 0...canvasRef.frameWidth)
			{
				for (j in 0...canvasRef.frameHeight)
				{
					setNoiseValue(i, j);
				}
			}
		}

		// FlxSprite doesn't know that we messed with `pixels`, so we mark it as dirty to let it know
		canvasRef.dirty = true;
	}

	/**
	 * "Scrolls" the displayed noise around, regenerating only the pixels that cannot be copied.
	 * @param dx Scroll direction in X (-1, 0, 1)
	 * @param dy Scroll direction in Y (-1, 0, 1)
	 */
	public function scrollSimplex(dx:Int, dy:Int):Void
	{
		dx *= scrollAmount;
		dy *= scrollAmount;

		x -= dx;
		y -= dy;

		// we can scroll the display and regenerate only the new pixels, instead of regenerating the entire display
		canvasRef.pixels.scroll(dx, dy);

		var startX = 0, endX = canvasRef.frameWidth;
		var startY = 0, endY = canvasRef.frameHeight;

		// this section marks which areas need to be regenerated and fills them in with new noise
		if (dx != 0)
		{
			if (dx < 0)
				startX = canvasRef.frameWidth + dx;
			else
				endX = dx;

			for (i in startX...endX)
			{
				for (j in 0...canvasRef.frameHeight)
				{
					setNoiseValue(i, j);
				}
			}
		}

		if (dy != 0)
		{
			if (dy < 0)
				startY = canvasRef.frameHeight + dy;
			else
				endY = dy;

			for (i in 0...canvasRef.frameWidth)
			{
				// we don't need to regenerate pixels if they were already regenerated by scrolling in X
				if (dx != 0 && i >= startX && i < endX)
					continue;

				for (j in startY...endY)
				{
					setNoiseValue(i, j);
				}
			}
		}

		canvasRef.dirty = true;
	}

	/**
	 * Sets a pixel's lightness based on the value of noise at that pixel.
	 * @param i The X coordinate of the pixel, relative to the top left pixel.
	 * @param j The Y coordinate of the pixel, relative to the top left pixel.
	 */
	function setNoiseValue(i:Int, j:Int):Void
	{
		var noise = if (!tile)
			FlxSimplex.simplexOctaves(x + i, y + j, scale, persistence, octaves);
		else
			FlxSimplex.simplexTiles(x + i, y + j, tileSize, tileSize, seed, scale, persistence, octaves);

		// simplex noise ranges from -1 to 1, but we want 0 to 1
		noise = (noise + 1) / 2;
		// the noise determines the amount of black per pixel in the canvas
		canvasRef.pixels.setPixel32(i, j, FlxColor.fromCMYK(0, 0, 0, noise, 1));
	}
}
