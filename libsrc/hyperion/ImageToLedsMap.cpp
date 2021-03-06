#include <hyperion/ImageToLedsMap.h>
#include <hyperion/ImageProcessor.h>

using namespace hyperion;

ImageToLedsMap::ImageToLedsMap(
		int mappingType,
		unsigned width,
		unsigned height,
		unsigned horizontalBorder,
		unsigned verticalBorder,
		const std::vector<Led>& leds)
	: _width(width)
	, _height(height)
	, _horizontalBorder(horizontalBorder)
	, _verticalBorder(verticalBorder)
	, _colorsMap()
{
	// Sanity check of the size of the borders (and width and height)
	Q_ASSERT(_width  > 2*_verticalBorder);
	Q_ASSERT(_height > 2*_horizontalBorder);
	Q_ASSERT(_width  < 10000);
	Q_ASSERT(_height < 10000);
	
	_mappingType = mappingType;

	// Reserve enough space in the map for the leds
	_colorsMap.reserve(leds.size());

	const unsigned xOffset      = _verticalBorder;
	const unsigned actualWidth  = _width  - 2 * _verticalBorder;
	const unsigned yOffset      = _horizontalBorder;
	const unsigned actualHeight = _height - 2 * _horizontalBorder;

	for (const Led& led : leds)
	{
		// skip leds without area
		if ((led.maxX_frac-led.minX_frac) < 1e-6 || (led.maxY_frac-led.minY_frac) < 1e-6)
		{
			_colorsMap.emplace_back();
			continue;
		}

		// Compute the index boundaries for this led
		unsigned minX_idx = xOffset + unsigned(qRound(actualWidth  * led.minX_frac));
		unsigned maxX_idx = xOffset + unsigned(qRound(actualWidth  * led.maxX_frac));
		unsigned minY_idx = yOffset + unsigned(qRound(actualHeight * led.minY_frac));
		unsigned maxY_idx = yOffset + unsigned(qRound(actualHeight * led.maxY_frac));

		// make sure that the area is at least a single led large
		minX_idx = qMin(minX_idx, xOffset + actualWidth - 1);
		if (minX_idx == maxX_idx)
		{
			maxX_idx++;
		}
		minY_idx = qMin(minY_idx, yOffset + actualHeight - 1);
		if (minY_idx == maxY_idx)
		{
			maxY_idx++;
		}

		// Add all the indices in the above defined rectangle to the indices for this led
		const auto maxYLedCount = qMin(maxY_idx, yOffset+actualHeight);
		const auto maxXLedCount = qMin(maxX_idx, xOffset+actualWidth);

		std::vector<int32_t> ledColors;
		ledColors.reserve((size_t) maxXLedCount*maxYLedCount);
		if (ImageProcessor::mappingTypeToInt(QString("weighted")) == _mappingType)
		{
			bool left   = led.minX_frac == 0;
			bool right  = led.maxX_frac == 1;			
			bool top    = led.minY_frac == 0;
			bool bottom = led.maxY_frac == 1;	
			
			if (bottom)
			{
				unsigned mid = (minY_idx+maxYLedCount)/2;
				for (unsigned y = minY_idx; y < mid; ++y)				
					for (unsigned x = minX_idx; x < maxXLedCount; ++x)					
						ledColors.push_back( -( (int32_t) (y*width + x)));
					
				for (unsigned y = mid; y < maxYLedCount; ++y)				
					for (unsigned x = minX_idx; x < maxXLedCount; ++x)					
						ledColors.push_back(y*width + x);									
			}
			else if (top)
			{
				unsigned mid = (minY_idx+maxYLedCount)/2;
				for (unsigned y = minY_idx; y < mid; ++y)				
					for (unsigned x = minX_idx; x < maxXLedCount; ++x)					
						ledColors.push_back(y*width + x);
					
				for (unsigned y = mid; y < maxYLedCount; ++y)				
					for (unsigned x = minX_idx; x < maxXLedCount; ++x)					
						ledColors.push_back( -( (int32_t) (y*width + x)));
			}

			else if (left)
			{
				unsigned mid = (minX_idx + maxXLedCount)/2;
				for (unsigned y = minY_idx; y < maxYLedCount; ++y)
				{				
					for (unsigned x = minX_idx; x < mid; ++x)					
						ledColors.push_back(y*width + x);
					for (unsigned x = mid; x < maxXLedCount; ++x)					
						ledColors.push_back( -( (int32_t) (y*width + x)));
				}					
			}

			else if (right)
			{
				unsigned mid = (minX_idx + maxXLedCount)/2;
				for (unsigned y = minY_idx; y < maxYLedCount; ++y)
				{				
					for (unsigned x = minX_idx; x < mid; ++x)					
						ledColors.push_back( -( (int32_t) (y*width + x)));
					for (unsigned x = mid; x < maxXLedCount; ++x)					
						ledColors.push_back(y*width + x);
				}
			}
								
		}
		else
		{
			for (unsigned y = minY_idx; y < maxYLedCount; ++y)
			{
				for (unsigned x = minX_idx; x < maxXLedCount; ++x)
				{
					ledColors.push_back(y*width + x);
				}
			}
		}

		// Add the constructed vector to the map
		_colorsMap.push_back(ledColors);
	}
}

unsigned ImageToLedsMap::width() const
{
	return _width;
}

unsigned ImageToLedsMap::height() const
{
	return _height;
}
