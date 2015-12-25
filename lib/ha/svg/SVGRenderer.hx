package lib.ha.svg;

import lib.ha.svg.SVGData;
import lib.ha.aggx.vectorial.InnerJoin;
import lib.ha.aggx.renderer.ScanlineRenderer;
import lib.ha.aggx.color.SpanGradient;
import lib.ha.svg.gradients.SVGGradient;
import lib.ha.aggx.renderer.SolidScanlineRenderer;
import lib.ha.aggx.rasterizer.FillingRule;
import lib.ha.aggx.color.RgbaColor;
import lib.ha.aggx.vectorial.CubicCurve;
import lib.ha.aggx.renderer.ClippingRenderer;
import lib.ha.aggx.rasterizer.IScanline;
import lib.ha.aggx.rasterizer.ScanlineRasterizer;
import lib.ha.aggx.color.SpanAllocator;
import lib.ha.aggx.color.SpanInterpolatorLinear;
import lib.ha.core.geometry.AffineTransformer;
import lib.ha.aggx.color.GradientRadialFocus;
import lib.ha.aggx.color.GradientX;
import lib.ha.svg.gradients.GradientManager;
import lib.ha.aggx.vectorial.converters.ConvContour;
import lib.ha.aggx.vectorial.converters.ConvTransform;
import lib.ha.aggx.vectorial.converters.ConvStroke;
import lib.ha.aggx.vectorial.converters.ConvCurve;

class SVGRenderer
{
    private var _curved: ConvCurve;

    private var _curved_stroked: ConvStroke;
    private var _curved_stroked_trans: ConvTransform;

    private var _curved_trans: ConvTransform;
    private var _curved_trans_contour: ConvContour;

    private var _gradientFunction: GradientX = new GradientX();
    private var _gradientRadialFocus: GradientRadialFocus = new GradientRadialFocus();
    private var _gradientMatrix: AffineTransformer = new AffineTransformer();
    private var _spanInterpolator: SpanInterpolatorLinear;
    private var _spanAllocator: SpanAllocator = new SpanAllocator();

    private var _transform: AffineTransformer;

    public function new()
    {
        //_curved = new ConvCurve(_storage);
        _curved = new ConvCurve();

        _curved_stroked = new ConvStroke(_curved);
        _curved_stroked_trans = new ConvTransform(_curved_stroked, _transform);

        _curved_trans = new ConvTransform(_curved, _transform);
        _curved_trans_contour = new ConvContour(_curved_trans);

        _curved_trans_contour.autoDetect = false;
        _spanInterpolator = new SpanInterpolatorLinear(_gradientMatrix);
        _transform = new AffineTransformer();
    }

    private function renderElement(element: SVGElement, data: SVGData, ras:ScanlineRasterizer, sl:IScanline, ren:ClippingRenderer, mtx: AffineTransformer, alpha: Float)
    {
        _transform.set(element.transform.sx, element.transform.shy, element.transform.shx, element.transform.sy, element.transform.tx, element.transform.ty);
        _transform.multiply(mtx);
        var scl: Float = _transform.scaling;
        _curved.approximationMethod = CubicCurve.CURVE_INC;
        _curved.approximationScale = scl;
        _curved.angleTolerance = 0.0;

        var color: RgbaColor = new RgbaColor();

        if (element.fill_flag)
        {
            ras.reset();
            ras.fillingRule = element.even_odd_flag ? FillingRule.FILL_EVEN_ODD : FillingRule.FILL_NON_ZERO;

            if (Math.abs(_curved_trans_contour.width) < 0.0001)
            {
                ras.addPath(_curved_trans, element.index);
            }
            else
            {
                _curved_trans_contour.miterLimit = element.miter_limit;
                ras.addPath(_curved_trans_contour, element.index);
            }

            color.set(element.fill_color);
            if (element.fill_opacity != null)
            {
                color.opacity = element.fill_opacity;
            }

            color.opacity = color.opacity * alpha;
            SolidScanlineRenderer.renderAASolidScanlines(ras, sl, ren, color);
        }

        var gradientManager: GradientManager = data.gradientManager;
        var gradient: SVGGradient;

        if (element.gradientId != null && (gradient = gradientManager.getGradient(element.gradientId)) != null)
        {
            ras.reset();
            ras.fillingRule = element.even_odd_flag ? FillingRule.FILL_EVEN_ODD : FillingRule.FILL_NON_ZERO;

            if (Math.abs(_curved_trans_contour.width) < 0.0001)
            {
                ras.addPath(_curved_trans, element.index);
            }
            else
            {
                _curved_trans_contour.miterLimit = element.miter_limit;
                ras.addPath(_curved_trans_contour, element.index);
            }

            var gradientSpan: SpanGradient;
            if (gradient.type == GradientType.Linear)
            {
                gradientManager.calculateLinearGradientTransform(element.gradientId, element.bounds, _transform, _gradientMatrix);
                gradientSpan = new SpanGradient(_spanInterpolator, _gradientFunction, gradientManager.getGradientColors(element.gradientId), 0, 100);
            }
            else
            {
                gradientManager.calculateRadialGradientParameters(element.gradientId, element.bounds, _transform, _gradientMatrix, _gradientRadialFocus);
                gradientSpan = new SpanGradient(_spanInterpolator, _gradientRadialFocus, gradientManager.getGradientColors(element.gradientId), 0, 100);
            }

            gradientSpan.spread = gradientManager.getSpreadMethod(element.gradientId);

            var gradientRenderer = new ScanlineRenderer(ren, _spanAllocator, gradientSpan);

            SolidScanlineRenderer.renderScanlines(ras, sl, gradientRenderer);
        }

        if (element.stroke_flag)
        {
            _curved_stroked.width = element.stroke_width;
            _curved_stroked.lineJoin = element.line_join;
            _curved_stroked.lineCap = element.line_cap;
            _curved_stroked.miterLimit = element.miter_limit;
            _curved_stroked.innerJoin = InnerJoin.ROUND;
            _curved_stroked.approximationScale = scl;

            // If the *visual* line width is considerable we
            // turn on processing of curve cusps.
            if(element.stroke_width * scl > 1.0)
            {
                _curved.angleTolerance = 0.2;
            }
            ras.reset();
            ras.fillingRule = FillingRule.FILL_NON_ZERO;
            ras.addPath(_curved_stroked_trans, element.index);
            color.set(element.stroke_color);
            color.opacity = color.opacity * alpha;
            SolidScanlineRenderer.renderAASolidScanlines(ras, sl, ren, color);
        }
    }

    public function render(data: SVGData, ras:ScanlineRasterizer, sl:IScanline, ren:ClippingRenderer, mtx: AffineTransformer, alpha: Float): Void
    {
        _curved_trans_contour.width = data.expandValue;
        _curved.attach(data.storage);

        for (elem in data.elementStorage)
        {
            renderElement(elem, data, ras, sl, ren, mtx, alpha);
        }

        _curved.attach(null);
    }
}
