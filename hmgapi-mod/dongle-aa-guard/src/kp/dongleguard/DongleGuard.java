package kp.dongleguard;

import android.content.Context;
import android.content.Intent;
import android.content.pm.ResolveInfo;
import android.hardware.usb.UsbDevice;
import android.hardware.usb.UsbManager;

import java.lang.reflect.Method;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import hmgapi.hook.Bridge;
import hmgapi.hook.LoadedApp;
import hmgapi.hook.MethodHook;
import hmgapi.hook.ModContext;
import hmgapi.hook.ModEntry;

/**
 * The stock Android Auto (GPM) answers every USB_DEVICE_ATTACHED by trying the Android
 * accessory protocol on the new device. A Realtek RTL8812BU dongle answers that probe with
 * its own register contents and takes the accessory strings as register writes (power and
 * clock control at 0x00), which hangs the chip until it loses power. So, in GPM only, the
 * manifest receivers of that broadcast skip it when the device is the dongle. Any problem
 * while hooking is logged and leaves GPM as stock. Off in the HMG-API app (hmgapid disable):
 * the hook lets everything through at once.
 */
public final class DongleGuard extends ModEntry {
    static final String GPM = "com.google.android.projection.sink";
    /** vendor:product of the dongles Korea Projection drives (Realtek RTL8812BU) */
    static final int VID = 0x0bda;
    static final int[] PIDS = {0xb812};

    static boolean isDongle(UsbDevice d) {
        if (d == null || d.getVendorId() != VID) return false;
        for (int p : PIDS) if (d.getProductId() == p) return true;
        return false;
    }

    @Override
    public void appLoaded(final ModContext mod, LoadedApp app) {
        if (!GPM.equals(app.packageName)) return;
        try {
            Intent q = new Intent(UsbManager.ACTION_USB_DEVICE_ATTACHED).setPackage(GPM);
            List<ResolveInfo> rs = app.context.getPackageManager().queryBroadcastReceivers(q, 0);
            Set<Method> done = new HashSet<Method>();
            if (rs != null) {
                for (ResolveInfo ri : rs) {
                    if (ri.activityInfo == null) continue;
                    Method m = onReceive(Class.forName(ri.activityInfo.name, false, app.classLoader));
                    if (m == null) {
                        mod.log("no onReceive in " + ri.activityInfo.name + ": not hooked");
                        continue;
                    }
                    if (!done.add(m)) continue;
                    Bridge.hookMethod(m, new MethodHook() {
                        @Override
                        protected void beforeHookedMethod(Param p) {
                            // turned off in the HMG-API app: stock from now on (a mod off at boot isn't loaded at all)
                            if (!mod.enabled()) return;
                            Intent i = p.args[1] instanceof Intent ? (Intent) p.args[1] : null;
                            if (i == null || !UsbManager.ACTION_USB_DEVICE_ATTACHED.equals(i.getAction())) return;
                            UsbDevice d = i.getParcelableExtra(UsbManager.EXTRA_DEVICE);
                            if (!isDongle(d)) return;
                            mod.log("USB Wi-Fi dongle attached (" + Integer.toHexString(d.getVendorId()) + ":"
                                    + Integer.toHexString(d.getProductId()) + "): Android Auto left it alone");
                            p.setResult(null);
                        }
                    });
                    mod.log("hooked " + m.getDeclaringClass().getName() + ".onReceive");
                }
            }
            if (done.isEmpty()) mod.log("no USB_DEVICE_ATTACHED receiver found in " + GPM + ": nothing hooked");
        } catch (Throwable t) {
            mod.log("not hooked, Android Auto stays stock: " + t);
        }
    }

    /** onReceive(Context, Intent) declared by the receiver class or the nearest app superclass */
    static Method onReceive(Class<?> c) {
        for (; c != null && !c.getName().equals("android.content.BroadcastReceiver"); c = c.getSuperclass()) {
            try {
                Method m = c.getDeclaredMethod("onReceive", Context.class, Intent.class);
                m.setAccessible(true);
                return m;
            } catch (NoSuchMethodException e) {
                // the superclass may declare it
            }
        }
        return null;
    }
}
