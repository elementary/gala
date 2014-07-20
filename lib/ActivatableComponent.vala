
namespace Gala
{
	/**
	 * Implement this interface on your {@link Plugin} class if you want to
	 * replace a component like the window overview or the multitasking view.
	 * It allows gala to hook up functionality like hotcorners and dbus
	 * invocation of your component.
	 */
	public interface ActivatableComponent : Object
	{
		/**
		 * The component was requested to be opened.
		 *
		 * @param hints The hashmap may contain special parameters that are useful
		 *              to the component. Currently, the only one implemented is the
		 *              'all-windows' hint to the windowoverview.
		 */
		public abstract void open (Gee.HashMap<string,Value?>? hints = null);

		/**
		 * The component was requested to be closed.
		 */
		public abstract void close ();

		/**
		 * Should return whether the component is currently opened. Used mainly for
		 * toggling by the window manager.
		 *
		 * @return Return true if the component is opened.
		 */
		public abstract bool is_opened ();
	}
}

