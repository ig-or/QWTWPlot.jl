#### Line styles info
Below is just a C++/QT/QWT code which can help you for create a line style

Style is a string with 1 or 2 or 3 symbols.
 * last symbol sets up a color
 * first is a line style
 * middle (if exists) is a symbol type

examples:
 * "-b" simple blue line
  * "-tr" triangles connected by line
  * " eg"  green circles (not connected)




		int sn = line->style.size();
		
		if (sn > 0) { //    last is always color:
			//  set color:
			switch (line->style[sn - 1]) {
				case 'r':  color = Qt::red;  break;
				case 'd': color = Qt::darkRed;	break;
				case 'k': color = Qt::black;  break;
				case 'w': color = Qt::white;  break;
				case 'g': color = Qt::green;  break;
				case 'G': color = Qt::darkGreen;  break;
				case 'm': color = Qt::magenta;   break;
				case 'M': color = Qt::darkMagenta;  break;
				case 'y': color = Qt::yellow;   break;
				case 'Y': color = Qt::darkYellow;  break;
				case 'b': color = Qt::blue;  break;
				case 'c': color = Qt::cyan;  break;
				case 'C': color = Qt::darkCyan;  break;
			};

			sym->setBrush(color);  
			sym->setPen(color); 
			pen.setColor(color); 

		}

		if (sn > 1) {  //  first is always a line style:
			switch (line->style[0]) {
			case ' ': cl->setStyle(QwtPlotCurve::NoCurve); break;
			case '-': cl->setStyle(QwtPlotCurve::Lines); break;
			case '%': cl->setStyle(QwtPlotCurve::Sticks); break;
			case '#': cl->setStyle(QwtPlotCurve::Steps); break;
			case '.': cl->setStyle(QwtPlotCurve::Dots); break;
			};

		}
		if (sn == 3) {  //   middle is symbol type
			switch (line->style[1]) {
			case 'e': sym->setStyle(QwtSymbol::Ellipse);  break;
			case 'r': sym->setStyle(QwtSymbol::Rect);  break;
			case 'd': sym->setStyle(QwtSymbol::Diamond);  break;
			case 't': sym->setStyle(QwtSymbol::Triangle);  break;
			case 'x': sym->setStyle(QwtSymbol::Cross);  break;
			case 's': sym->setStyle(QwtSymbol::Star1);  break;
			case 'q': sym->setStyle(QwtSymbol::Star2);  break;
			case 'w': sym->setStyle(QwtSymbol::XCross);  break;
			case 'u': sym->setStyle(QwtSymbol::UTriangle);  break;
			};

		}

