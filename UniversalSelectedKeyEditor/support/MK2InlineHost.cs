using System;
using System.Drawing;
using System.Windows.Forms;

namespace USKE.MK2
{
    // Keep native-handle lookup and parenting inside .NET. Returning the host to
    // MAXScript can turn it back into a rollout dotNetControl proxy.
    public static class InlineHost
    {
        public static bool Show(IntPtr parentHandle, Control editor, int x, int y, int width, int height)
        {
            Control parent = Control.FromHandle(parentHandle);
            if (parent == null || editor == null || editor.IsDisposed) return false;
            if (editor.Parent != parent) parent.Controls.Add(editor);
            editor.Bounds = new Rectangle(x, y, width, height);
            editor.Visible = true;
            editor.BringToFront();
            editor.Focus();
            TextBox box = editor as TextBox;
            if (box != null) box.SelectAll();
            return editor.Visible && editor.Focused;
        }
    }
}
