import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import St from 'gi://St';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import { Extension } from 'resource:///org/gnome/shell/extensions/extension.js';

const BUS_NAME = 'org.gnome.Shell.Extensions.RamAlert';
const OBJECT_PATH = '/org/gnome/Shell/Extensions/RamAlert';
const INTERFACE_XML = `
<node>
  <interface name="org.gnome.Shell.Extensions.RamAlert">
    <method name="Flash">
      <arg name="duration_ms" type="i" direction="in"/>
    </method>
  </interface>
</node>`;

class RamAlertDBusService {
    constructor(extension) {
        this._extension = extension;
    }

    Flash(durationMs) {
        this._extension.flash(durationMs);
    }
}

export default class RamAlertExtension extends Extension {
    enable() {
        this._panel = Main.panel;
        this._panel.add_style_class_name('ram-alert-panel');
        this._stylesheet = this.dir.get_child('stylesheet.css');
        this._theme = St.ThemeContext.get_for_stage(global.stage).get_theme();
        this._theme.load_stylesheet(this._stylesheet);

        this._toggleId = 0;
        this._stopId = 0;
        this._exported = false;
        this._dbus = Gio.DBusExportedObject.wrapJSObject(
            INTERFACE_XML,
            new RamAlertDBusService(this),
        );
        this._ownerId = Gio.bus_own_name(
            Gio.BusType.SESSION,
            BUS_NAME,
            Gio.BusNameOwnerFlags.NONE,
            connection => {
                this._dbus.export(connection, OBJECT_PATH);
                this._exported = true;
            },
            null,
            (_connection, _name) => {
                console.error('ram-alert could not acquire its D-Bus name');
            },
        );
    }

    flash(durationMs) {
        if (!this._panel)
            return;

        const duration = Math.max(1000, Math.min(30000, Number(durationMs) || 10000));
        this._clearFlashTimers();
        this._panel.remove_style_class_name('ram-alert-flash');

        this._toggleId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 300, () => {
            if (!this._panel)
                return GLib.SOURCE_REMOVE;
            if (this._panel.has_style_class_name('ram-alert-flash'))
                this._panel.remove_style_class_name('ram-alert-flash');
            else
                this._panel.add_style_class_name('ram-alert-flash');
            return GLib.SOURCE_CONTINUE;
        });
        this._stopId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, duration, () => {
            this._stopId = 0;
            if (this._toggleId) {
                GLib.source_remove(this._toggleId);
                this._toggleId = 0;
            }
            if (this._panel)
                this._panel.remove_style_class_name('ram-alert-flash');
            return GLib.SOURCE_REMOVE;
        });
    }

    _clearFlashTimers() {
        if (this._toggleId) {
            GLib.source_remove(this._toggleId);
            this._toggleId = 0;
        }
        if (this._stopId) {
            const id = this._stopId;
            this._stopId = 0;
            GLib.source_remove(id);
        }
    }

    disable() {
        this._clearFlashTimers();
        if (this._panel) {
            this._panel.remove_style_class_name('ram-alert-flash');
            this._panel.remove_style_class_name('ram-alert-panel');
        }
        this._panel = null;

        if (this._ownerId) {
            Gio.bus_unown_name(this._ownerId);
            this._ownerId = 0;
        }
        if (this._dbus && this._exported) {
            this._dbus.unexport();
            this._exported = false;
        }
        if (this._stylesheet && this._theme)
            this._theme.unload_stylesheet(this._stylesheet);
        this._stylesheet = null;
        this._theme = null;
        this._dbus = null;
    }
}
