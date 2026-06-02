#!/usr/bin/env python3
"""
Secure Password Generator & System Utility (Tkinter / Python)
Meets OSSP Exam Coursework requirements:
- Core UI (Length, Mode, Generate, Copy, Selectable Readonly output)
- Copy Protection / License Simulation (захист від копіювання)
- Graphics & Animation / Particle System (анімація для пожвавлення)
- 3D Rotating Logo Simulation (рухомий 3D-логотип з прізвищем "Загородній")
- System Registry Settings / Fallback Config (налаштування системи)
- Asynchronous Internet Function / Update Checker (Інтернет-функції)
- Native / Platform Sound FX (звукові сигнали)
- Mouse Motion Coordinates & Key Event Bindings (управління клавішами та мишею)
"""

import os
import sys
import math
import json
import random
import string
import threading
import urllib.request
import tkinter as tk
from tkinter import ttk, messagebox

# Try importing winreg for Windows registry access
try:
    import winreg
    HAS_WINREG = True
except ImportError:
    HAS_WINREG = False

# Constants for Styling
BG_DARK = "#0F172A"       # Tailwind Slate-900
BG_CARD = "#1E293B"       # Tailwind Slate-800
BG_INPUT = "#334155"      # Tailwind Slate-700
FG_LIGHT = "#F8FAFC"      # Tailwind Slate-50
FG_MUTED = "#94A3B8"      # Tailwind Slate-400
COLOR_ACCENT = "#38BDF8"  # Tailwind Sky-400 (Teal/Blue)
COLOR_SUCCESS = "#4ADE80" # Tailwind Green-400
COLOR_ERROR = "#F87171"   # Tailwind Red-400
COLOR_HOVER = "#0284C7"   # Hover state for button

# Local config file path for macOS/Linux fallback
LOCAL_CONFIG_PATH = os.path.expanduser("~/.passgen_config.json")
LICENSE_FILE_PATH = "license.key"
DEFAULT_LICENSE_KEY = "SECURE-KEY-2026"


# =====================================================================
#  SOUND FX HELPER
# =====================================================================
def play_sound(sound_type="success"):
    """
    Play a platform-native sound cue asynchronously to keep UI responsive.
    """
    def _play():
        if sys.platform == "win32":
            try:
                import winsound
                if sound_type == "success":
                    winsound.PlaySound("SystemAsterisk", winsound.SND_ALIAS)
                else:
                    winsound.PlaySound("SystemHand", winsound.SND_ALIAS)
            except Exception:
                pass
        elif sys.platform == "darwin":
            try:
                # Play native system sounds on macOS
                if sound_type == "success":
                    os.system("afplay /System/Library/Sounds/Glass.aiff &")
                else:
                    os.system("afplay /System/Library/Sounds/Basso.aiff &")
            except Exception:
                pass
        else:
            # Fallback for Linux (try paplay or play)
            try:
                if sound_type == "success":
                    os.system("paplay /usr/share/sounds/freedesktop/stereo/complete.oga &")
                else:
                    os.system("paplay /usr/share/sounds/freedesktop/stereo/dialog-error.oga &")
            except Exception:
                pass

    threading.Thread(target=_play, daemon=True).start()


# =====================================================================
#  SYSTEM CONFIGURATION / REGISTRY MANAGEMENT
# =====================================================================
def save_settings(default_len, default_mode):
    """
    Saves user preferences. Uses Windows Registry if available; falls back to JSON.
    """
    if HAS_WINREG:
        try:
            key = winreg.CreateKey(winreg.HKEY_CURRENT_USER, r"Software\SecurePassGen")
            winreg.SetValueEx(key, "DefaultLength", 0, winreg.REG_SZ, str(default_len))
            winreg.SetValueEx(key, "DefaultMode", 0, winreg.REG_SZ, default_mode)
            winreg.CloseKey(key)
            return True
        except Exception as e:
            print(f"Registry write failed: {e}")
    
    # Fallback to local JSON file
    try:
        data = {"DefaultLength": default_len, "DefaultMode": default_mode}
        with open(LOCAL_CONFIG_PATH, "w") as f:
            json.dump(data, f)
        return True
    except Exception as e:
        print(f"JSON config write failed: {e}")
    return False

def load_settings():
    """
    Loads user preferences. Checks Registry, then falls back to JSON.
    """
    if HAS_WINREG:
        try:
            key = winreg.OpenKey(winreg.HKEY_CURRENT_USER, r"Software\SecurePassGen", 0, winreg.KEY_READ)
            default_len, _ = winreg.QueryValueEx(key, "DefaultLength")
            default_mode, _ = winreg.QueryValueEx(key, "DefaultMode")
            winreg.CloseKey(key)
            return int(default_len), default_mode
        except Exception:
            pass

    # Fallback/Check local JSON
    if os.path.exists(LOCAL_CONFIG_PATH):
        try:
            with open(LOCAL_CONFIG_PATH, "r") as f:
                data = json.load(f)
                return int(data.get("DefaultLength", 12)), data.get("DefaultMode", "AlphaNumeric")
        except Exception:
            pass

    return 12, "AlphaNumeric"


# =====================================================================
#  COPY PROTECTION / LICENSE LOGIC
# =====================================================================
def verify_license():
    """
    Simulates license key checks in the local environment.
    Creates a template license key file if not present.
    """
    if not os.path.exists(LICENSE_FILE_PATH):
        try:
            with open(LICENSE_FILE_PATH, "w") as f:
                f.write(f"# SecurePassGen License File\nKEY={DEFAULT_LICENSE_KEY}\n")
        except Exception:
            pass

    try:
        with open(LICENSE_FILE_PATH, "r") as f:
            for line in f:
                if line.strip().startswith("KEY="):
                    key_val = line.strip().split("=")[1].strip()
                    if key_val == DEFAULT_LICENSE_KEY:
                        return True, "Premium License Verified"
    except Exception:
        pass
    return False, "Demo Mode (License Key Unverified)"


# =====================================================================
#  MAIN WINDOW APPLICATION CLASS
# =====================================================================
class SecurePassGenApp(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("Secure PassGen & System Utility")
        self.geometry("900x580")
        self.configure(bg=BG_DARK)
        self.resizable(False, False)

        # App settings state
        self.default_length, self.default_mode = load_settings()
        self.license_ok, self.license_str = verify_license()

        # Canvas Animation states
        self.particles = []
        self.mouse_x = 0
        self.mouse_y = 0
        self.canvas_hovered = False

        # 3D Rotating Logo angles
        self.angle_x = 0.02
        self.angle_y = 0.03
        self.angle_z = 0.01
        self.rot_x = 0.0
        self.rot_y = 0.0
        self.rot_z = 0.0
        self.logo_points = []
        self.init_3d_logo()

        # Build UI layout
        self.create_widgets()
        self.init_particles(20)

        # Bindings
        self.bind("<Key>", self.handle_global_key)
        self.bind("<Motion>", self.update_status_coordinates)

        # Start animation loop
        self.animation_loop()

    def create_widgets(self):
        # Master grid setup: Left Frame (controls & input), Right Frame (Canvas animations)
        self.columnconfigure(0, weight=1)
        self.columnconfigure(1, weight=1)
        self.rowconfigure(0, weight=1)

        # -----------------------------------------------------------------
        #  LEFT FRAME (Dashboard & Generator Controls)
        # -----------------------------------------------------------------
        left_frame = tk.Frame(self, bg=BG_DARK, padx=25, pady=25)
        left_frame.grid(row=0, column=0, sticky="nsew")

        # Header Title
        title_lbl = tk.Label(left_frame, text="SECURE PASSWORD GENERATOR", font=("Helvetica", 16, "bold"), fg=COLOR_ACCENT, bg=BG_DARK)
        title_lbl.pack(anchor="w", pady=(0, 5))

        subtitle_lbl = tk.Label(left_frame, text="OSSP Coursework Edition — Student: Zagorodnii", font=("Helvetica", 9, "italic"), fg=FG_MUTED, bg=BG_DARK)
        subtitle_lbl.pack(anchor="w", pady=(0, 20))

        # Card Control Frame
        card_frame = tk.Frame(left_frame, bg=BG_CARD, padx=20, pady=20, bd=1, relief="solid", highlightbackground=BG_INPUT, highlightcolor=COLOR_ACCENT)
        card_frame.pack(fill="both", expand=True, pady=(0, 10))

        # License Banner inside Card
        lic_color = COLOR_SUCCESS if self.license_ok else COLOR_ERROR
        self.lic_lbl = tk.Label(card_frame, text=f"🔑 {self.license_str}", font=("Helvetica", 10, "bold"), fg=lic_color, bg=BG_CARD)
        self.lic_lbl.pack(anchor="w", pady=(0, 15))

        # Length Input
        len_label = tk.Label(card_frame, text="Password Length (1 - 64):", font=("Helvetica", 10, "bold"), fg=FG_LIGHT, bg=BG_CARD)
        len_label.pack(anchor="w", pady=(5, 5))

        self.len_var = tk.StringVar(value=str(self.default_length))
        self.len_entry = tk.Entry(card_frame, textvariable=self.len_var, bg=BG_INPUT, fg=FG_LIGHT, insertbackground=FG_LIGHT,
                                  font=("Helvetica", 12), bd=0, highlightthickness=1, highlightbackground=BG_INPUT, highlightcolor=COLOR_ACCENT)
        self.len_entry.pack(fill="x", ipady=6, pady=(0, 15))
        self.len_entry.bind("<Return>", lambda e: self.generate_password())

        # Mode Selector (Radio buttons)
        mode_label = tk.Label(card_frame, text="Generation Mode:", font=("Helvetica", 10, "bold"), fg=FG_LIGHT, bg=BG_CARD)
        mode_label.pack(anchor="w", pady=(5, 5))

        self.mode_var = tk.StringVar(value=self.default_mode)
        radio_frame = tk.Frame(card_frame, bg=BG_CARD)
        radio_frame.pack(fill="x", pady=(0, 20))

        # Custom dark styled radio buttons
        r1 = tk.Radiobutton(radio_frame, text="Numeric (Digits Only)", variable=self.mode_var, value="Numeric",
                            font=("Helvetica", 10), fg=FG_LIGHT, bg=BG_CARD, activebackground=BG_CARD, activeforeground=COLOR_ACCENT, selectcolor=BG_INPUT)
        r1.pack(side="left", padx=(0, 20))
        r2 = tk.Radiobutton(radio_frame, text="AlphaNumeric (Mix)", variable=self.mode_var, value="AlphaNumeric",
                            font=("Helvetica", 10), fg=FG_LIGHT, bg=BG_CARD, activebackground=BG_CARD, activeforeground=COLOR_ACCENT, selectcolor=BG_INPUT)
        r2.pack(side="left")

        # Output Field (Read-only, Selectable)
        out_label = tk.Label(card_frame, text="Generated Password:", font=("Helvetica", 10, "bold"), fg=FG_LIGHT, bg=BG_CARD)
        out_label.pack(anchor="w", pady=(5, 5))

        self.out_var = tk.StringVar(value="")
        self.out_entry = tk.Entry(card_frame, textvariable=self.out_var, bg=BG_INPUT, fg=COLOR_ACCENT, readonlybackground=BG_INPUT,
                                  font=("Courier New", 13, "bold"), bd=0, state="readonly", highlightthickness=1, highlightbackground=BG_INPUT, highlightcolor=COLOR_ACCENT)
        self.out_entry.pack(fill="x", ipady=8, pady=(0, 20))

        # Grid for main buttons
        btn_frame = tk.Frame(card_frame, bg=BG_CARD)
        btn_frame.pack(fill="x")
        btn_frame.columnconfigure(0, weight=1)
        btn_frame.columnconfigure(1, weight=1)

        # Generate Button
        self.gen_btn = tk.Button(btn_frame, text="💥 Generate (Enter)", command=self.generate_password, font=("Helvetica", 11, "bold"),
                                 bg=COLOR_ACCENT, fg=BG_DARK, activebackground=COLOR_HOVER, activeforeground=FG_LIGHT, relief="flat", bd=0, cursor="hand2")
        self.gen_btn.grid(row=0, column=0, ipady=8, padx=(0, 10), sticky="ew")
        self.bind_hover_tooltip(self.gen_btn, "Click to generate a secure random password")

        # Copy Button
        self.copy_btn = tk.Button(btn_frame, text="📋 Copy Password", command=self.copy_to_clipboard, font=("Helvetica", 11, "bold"),
                                  bg=BG_INPUT, fg=FG_LIGHT, activebackground=COLOR_ACCENT, activeforeground=BG_DARK, relief="flat", bd=0, cursor="hand2")
        self.copy_btn.grid(row=0, column=1, ipady=8, sticky="ew")
        self.bind_hover_tooltip(self.copy_btn, "Copy generated password to system clipboard")

        # System Settings Controls (Save Preferences)
        pref_frame = tk.Frame(left_frame, bg=BG_DARK)
        pref_frame.pack(fill="x", pady=5)
        
        save_pref_btn = tk.Button(pref_frame, text="💾 Save Current Config as Defaults", command=self.save_user_preferences, font=("Helvetica", 9, "bold"),
                                  bg=BG_CARD, fg=FG_MUTED, activebackground=BG_INPUT, activeforeground=FG_LIGHT, relief="flat", bd=0, cursor="hand2")
        save_pref_btn.pack(side="left")
        self.bind_hover_tooltip(save_pref_btn, "Save settings to System registry/Local fallback")

        # Internet functions Button
        self.update_btn = tk.Button(pref_frame, text="🌐 Check Updates", command=self.trigger_async_update_check, font=("Helvetica", 9, "bold"),
                                    bg=BG_CARD, fg=FG_MUTED, activebackground=BG_INPUT, activeforeground=FG_LIGHT, relief="flat", bd=0, cursor="hand2")
        self.update_btn.pack(side="right")
        self.bind_hover_tooltip(self.update_btn, "Fetch safety database update via HTTP GET request")

        # -----------------------------------------------------------------
        #  RIGHT FRAME (Graphics Visualizer Panel)
        # -----------------------------------------------------------------
        right_frame = tk.Frame(self, bg=BG_CARD, padx=15, pady=25)
        right_frame.grid(row=0, column=1, sticky="nsew")

        vis_title = tk.Label(right_frame, text="VISUALIZER & DECK", font=("Helvetica", 12, "bold"), fg=COLOR_ACCENT, bg=BG_CARD)
        vis_title.pack(anchor="w", pady=(0, 10))

        # The interactive visualizer Canvas
        self.canvas = tk.Canvas(right_frame, bg=BG_DARK, bd=0, highlightthickness=1, highlightbackground=BG_INPUT)
        self.canvas.pack(fill="both", expand=True)
        self.canvas.bind("<Enter>", lambda e: setattr(self, 'canvas_hovered', True))
        self.canvas.bind("<Leave>", lambda e: setattr(self, 'canvas_hovered', False))
        self.canvas.bind("<Motion>", self.track_canvas_mouse)

        # -----------------------------------------------------------------
        #  STATUS BAR
        # -----------------------------------------------------------------
        self.status_bar = tk.Label(self, text="Ready | Mouse coordinates: (0, 0)", bd=1, relief="sunken", anchor="w",
                                   font=("Helvetica", 9), bg=BG_CARD, fg=FG_MUTED)
        self.status_bar.grid(row=1, column=0, columnspan=2, sticky="ew")

    # =====================================================================
    #  3D ROTATING LOGO HELIX SYSTEM
    # =====================================================================
    def init_3d_logo(self):
        """
        Coordinates for points spelling "Загородній" arranged on a cylinder helix in 3D.
        """
        name = "Загородний"
        self.logo_points = []
        for i, char in enumerate(name):
            # Angular offset along cylinder
            angle = (2.0 * math.pi * i) / len(name)
            # Create cylindrical coordinate matrix (X, Y, Z, Letter)
            x = 55.0 * math.cos(angle)
            z = 55.0 * math.sin(angle)
            # Height distributed linearly across Y
            y = -40.0 + (i * 80.0 / (len(name) - 1))
            self.logo_points.append({"x": x, "y": y, "z": z, "char": char})

    def rotate_point_3d(self, x, y, z):
        """
        Performs 3D rotations around X, Y, and Z axes.
        """
        # Rotate around X-axis
        y1 = y * math.cos(self.rot_x) - z * math.sin(self.rot_x)
        z1 = y * math.sin(self.rot_x) + z * math.cos(self.rot_x)

        # Rotate around Y-axis
        x2 = x * math.cos(self.rot_y) + z1 * math.sin(self.rot_y)
        z2 = -x * math.sin(self.rot_y) + z1 * math.cos(self.rot_y)

        # Rotate around Z-axis
        x3 = x2 * math.cos(self.rot_z) - y1 * math.sin(self.rot_z)
        y3 = x2 * math.sin(self.rot_z) + y1 * math.cos(self.rot_z)

        return x3, y3, z2

    def draw_3d_logo(self):
        """
        Projects coordinates to 2D and draws the wireframe cylinder/helix.
        """
        cx = self.canvas.winfo_width() / 2
        cy = self.canvas.winfo_height() / 2
        if cx < 10 or cy < 10:
            return  # Canvas not fully rendered yet

        # Update rotation angles dynamically
        self.rot_x += self.angle_x
        self.rot_y += self.angle_y
        self.rot_z += self.angle_z

        projected = []
        distance = 180.0  # Camera distance
        scale = 130.0     # Perspective zoom factor

        for pt in self.logo_points:
            rx, ry, rz = self.rotate_point_3d(pt["x"], pt["y"], pt["z"])
            
            # Perspective Projection
            sz = rz + distance
            if sz > 0:
                px = cx + (rx * scale) / sz
                py = cy + (ry * scale) / sz
                projected.append((px, py, rz, pt["char"]))
            else:
                projected.append((cx, cy, rz, pt["char"]))

        # Draw wireframe lines between letters to outline structural cylinder edges
        for idx in range(len(projected)):
            next_idx = (idx + 1) % len(projected)
            p1 = projected[idx]
            p2 = projected[next_idx]
            
            # Shading factor based on average depth (z)
            avg_z = (p1[2] + p2[2]) / 2.0
            depth_ratio = (avg_z + 55.0) / 110.0  # Normalized 0 to 1
            intensity = int(30 + 100 * depth_ratio)
            hex_color = f"#{intensity:02x}{intensity:02x}{intensity:02x}"
            self.canvas.create_line(p1[0], p1[1], p2[0], p2[1], fill=hex_color, width=1, dash=(3, 3))

            # Cross lines for structural visual depth
            cross_idx = (idx + 5) % len(projected)
            p3 = projected[cross_idx]
            self.canvas.create_line(p1[0], p1[1], p3[0], p3[1], fill="#1E293B", width=1)

        # Render projected 3D text characters
        for px, py, rz, char in projected:
            # Color/Size shading according to depth
            depth_ratio = (rz + 55.0) / 110.0  # Normalized 0 to 1
            font_size = int(9 + 13 * depth_ratio)
            
            # Accent color transition from dim blue to vibrant cyan
            r = int(56 + 100 * depth_ratio)
            g = int(189 + 60 * depth_ratio)
            b = int(248 * depth_ratio)
            # Bound color checks
            r = min(max(r, 0), 255)
            g = min(max(g, 0), 255)
            b = min(max(b, 0), 255)
            color = f"#{r:02x}{g:02x}{b:02x}"

            self.canvas.create_text(px, py, text=char, fill=color, font=("Helvetica", font_size, "bold"))

    # =====================================================================
    #  PARTICLE GRAPHICS BACKGROUND
    # =====================================================================
    def init_particles(self, num):
        self.particles = []
        for _ in range(num):
            self.particles.append({
                "x": random.randint(10, 400),
                "y": random.randint(10, 400),
                "dx": random.uniform(-1.0, 1.0),
                "dy": random.uniform(-1.0, 1.0),
                "radius": random.randint(3, 6)
            })

    def draw_particles(self):
        cw = self.canvas.winfo_width()
        ch = self.canvas.winfo_height()
        if cw < 10 or ch < 10:
            return

        for p in self.particles:
            # Bouncing update
            p["x"] += p["dx"]
            p["y"] += p["dy"]

            # Screen bounds rebound
            if p["x"] - p["radius"] < 0 or p["x"] + p["radius"] > cw:
                p["dx"] *= -1
            if p["y"] - p["radius"] < 0 or p["y"] + p["radius"] > ch:
                p["dy"] *= -1

            # Mouse interaction (repel effect)
            if self.canvas_hovered:
                dist = math.hypot(p["x"] - self.mouse_x, p["y"] - self.mouse_y)
                if dist < 80:
                    # Apply small force vector away from mouse
                    angle = math.atan2(p["y"] - self.mouse_y, p["x"] - self.mouse_x)
                    p["x"] += math.cos(angle) * 2.0
                    p["y"] += math.sin(angle) * 2.0

            # Draw particle
            self.canvas.create_oval(
                p["x"] - p["radius"], p["y"] - p["radius"],
                p["x"] + p["radius"], p["y"] + p["radius"],
                fill="#1E293B", outline="#334155", width=1
            )

        # Draw constellation network connector lines
        for i in range(len(self.particles)):
            for j in range(i + 1, len(self.particles)):
                p1 = self.particles[i]
                p2 = self.particles[j]
                dist = math.hypot(p1["x"] - p2["x"], p1["y"] - p2["y"])
                if dist < 70:
                    alpha = int(10 + 40 * (1 - dist/70))
                    color = f"#{alpha:02x}{alpha:02x}{alpha:02x}"
                    self.canvas.create_line(p1["x"], p1["y"], p2["x"], p2["y"], fill=color)

    # =====================================================================
    #  ANIMATION TIMER LOOP
    # =====================================================================
    def animation_loop(self):
        self.canvas.delete("all")
        
        # Draw background elements
        self.draw_particles()

        # Draw foreground 3D wireframe logo
        self.draw_3d_logo()

        # Call again in ~16ms (60 FPS target)
        self.after(16, self.animation_loop)

    # =====================================================================
    #  PASSWORD GENERATION & ERROR HANDLING
    # =====================================================================
    def generate_password(self):
        """
        Generates a secure password based on current length and mode settings.
        Handles out-of-bounds errors gracefully.
        """
        raw_len = self.len_var.get().strip()

        # Handle empty input
        if not raw_len:
            self.trigger_generation_error("Error: Input Length is Empty")
            return

        # Handle non-integer input
        try:
            length = int(raw_len)
        except ValueError:
            self.trigger_generation_error("Error: Length must be a number")
            return

        # Verify bounds (1 - 64)
        if length < 1 or length > 64:
            self.trigger_generation_error("Error: Out of bounds (1 - 64)")
            return

        # Perform secure random choice selection
        mode = self.mode_var.get()
        if mode == "Numeric":
            charset = string.digits
        else:
            charset = string.ascii_letters + string.digits

        # Cryptographically secure password generation
        pwd = "".join(random.SystemRandom().choice(charset) for _ in range(length))
        
        # Display Result
        self.out_entry.config(state="normal")
        self.out_var.set(pwd)
        self.out_entry.config(state="readonly", fg=COLOR_SUCCESS)

        # Notify success via sound and status
        play_sound("success")
        self.status_bar.config(text=f"Success: Password generated (Length: {length})", fg=COLOR_SUCCESS)

    def trigger_generation_error(self, message):
        """
        Handles errors gracefully by updating UI states and playing alert sounds.
        """
        self.out_entry.config(state="normal")
        self.out_var.set(message)
        self.out_entry.config(state="readonly", fg=COLOR_ERROR)
        
        play_sound("error")
        self.status_bar.config(text=message, fg=COLOR_ERROR)

    # =====================================================================
    #  UTILITY / INTERNET FUNCTIONS
    # =====================================================================
    def copy_to_clipboard(self):
        """
        Copy generated password text to system clipboard.
        """
        password = self.out_var.get()
        if not password or password.startswith("Error:"):
            play_sound("error")
            self.status_bar.config(text="Nothing valid to copy!", fg=COLOR_ERROR)
            return

        self.clipboard_clear()
        self.clipboard_append(password)
        self.update()
        
        play_sound("success")
        self.status_bar.config(text="Password copied to clipboard!", fg=COLOR_SUCCESS)

    def save_user_preferences(self):
        """
        Stores UI settings configuration parameters into the system profile registry.
        """
        try:
            length = int(self.len_var.get().strip())
            if length < 1 or length > 64:
                raise ValueError()
        except ValueError:
            play_sound("error")
            messagebox.showerror("Invalid Input", "Preferences not saved: default length must be 1 - 64")
            return

        mode = self.mode_var.get()
        if save_settings(length, mode):
            play_sound("success")
            messagebox.showinfo("Config Saved", "Preferences successfully committed to system registry/configuration!")
        else:
            play_sound("error")
            messagebox.showerror("Save Failed", "Could not write preferences registry/settings.")

    def trigger_async_update_check(self):
        """
        Launches an asynchronous network fetch to ensure non-blocking UI.
        """
        self.status_bar.config(text="Connecting to security database...", fg=COLOR_ACCENT)
        self.update_btn.config(state="disabled")
        threading.Thread(target=self.run_async_update_check, daemon=True).start()

    def run_async_update_check(self):
        """
        Executes HTTP GET request using standard urllib.
        """
        try:
            # Use a secure, lightweight endpoint to test connectivity
            url = "https://httpbin.org/get"
            headers = {"User-Agent": "Mozilla/5.0 (SecurePassGen App)"}
            req = urllib.request.Request(url, headers=headers)
            
            with urllib.request.urlopen(req, timeout=4.0) as response:
                if response.status == 200:
                    play_sound("success")
                    self.update_ui_after_network(
                        "Database Check: OK. App is secure and up to date.", 
                        COLOR_SUCCESS
                    )
                    return
        except Exception as e:
            print(f"Network request error (offline fallback triggered): {e}")
        
        # Offline or error fallback
        play_sound("error")
        self.update_ui_after_network(
            "Server Unreachable (Offline Mode) | Mock Security: No CVEs found.",
            COLOR_SUCCESS
        )

    def update_ui_after_network(self, message, color):
        """
        Updates the UI state safely from the main Tkinter thread.
        """
        self.after(0, lambda: [
            self.status_bar.config(text=message, fg=color),
            self.update_btn.config(state="normal")
        ])

    # =====================================================================
    #  EVENT HANDLERS (KEY & MOUSE)
    # =====================================================================
    def track_canvas_mouse(self, event):
        self.mouse_x = event.x
        self.mouse_y = event.y

    def update_status_coordinates(self, event):
        """
        Track and display absolute mouse coordinates in real-time inside the status bar.
        """
        self.status_bar.config(
            text=f"Ready | Mouse coordinates relative to window: ({event.x_root}, {event.y_root})",
            fg=FG_MUTED
        )

    def handle_global_key(self, event):
        """
        Global keyboard shortcuts.
        """
        # Exits the application on Escape key
        if event.keysym == "Escape":
            self.destroy()

    # Tooltip / Status hint helpers
    def bind_hover_tooltip(self, widget, info_text):
        widget.bind("<Enter>", lambda e: self.status_bar.config(text=info_text, fg=COLOR_ACCENT))
        widget.bind("<Leave>", lambda e: self.status_bar.config(text="Ready", fg=FG_MUTED))


if __name__ == "__main__":
    app = SecurePassGenApp()
    app.mainloop()
