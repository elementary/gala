
namespace Gala
{
	public interface Plugin : Object
	{
		public abstract X.Xrectangle[] region { get; protected set; }
		public abstract void initialize (WindowManager wm);
		public abstract void destroy ();
	}
}

