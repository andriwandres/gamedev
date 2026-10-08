using Godot;
using System;

public partial class RigidBody2dPill : RigidBody2D
{
	[Signal]
	public delegate void CrushedEventHandler(float force);

	[Export] public float ForceThreshold { get; set; } = 5000f;
	[Export] public Color BloodColor { get; set; } = new Color(0.55f, 0f, 0f);
	[Export] public int StreakCount { get; set; } = 25;

	private bool _triggered = false;
	private readonly RandomNumberGenerator _rng = new();

	public override void _Ready()
	{
		ContactMonitor = true;
		MaxContactsReported = 8;
		_rng.Randomize();
	}

	public override void _IntegrateForces(PhysicsDirectBodyState2D state)
	{
		if (_triggered) return;

		float totalImpulse = 0f;
		float strongest = 0f;
		Node2D offender = null;
		Vector2 hitPos = Vector2.Zero;

		for (int i = 0; i < state.GetContactCount(); i++)
		{
			if (state.GetContactColliderObject(i) is not Node2D other || !other.IsInGroup("house"))
				continue;

			float mag = state.GetContactImpulse(i).Length();
			totalImpulse += mag;

			if (mag > strongest)
			{
				strongest = mag;
				offender = other;
				hitPos = state.GetContactColliderPosition(i); // global contact point
			}
		}

		float force = totalImpulse / (float)state.Step;

		if (force > ForceThreshold && offender != null)
		{
			_triggered = true;
			// Don't add/remove nodes mid-physics-step; defer to after it.
			Vector2 center = state.Transform.Origin;
			Callable.From(() => Burst(offender, hitPos, center, force)).CallDeferred();
		}
	}

	private void Burst(Node2D offender, Vector2 hitPos, Vector2 center, float force)
	{
		EmitSignal(SignalName.Crushed, force);
		SpawnSplatter(center);
		PaintStreaks(offender, hitPos, (hitPos - center).Normalized());
		QueueFree();
	}

	private void SpawnSplatter(Vector2 at)
	{
		var particles = new CpuParticles2D
		{
			OneShot = true,
			Explosiveness = 1f,
			Amount = 60,
			Lifetime = 1.2f,
			Spread = 180f,
			InitialVelocityMin = 150f,
			InitialVelocityMax = 450f,
			Gravity = new Vector2(0, 980),
			ScaleAmountMin = 2f,
			ScaleAmountMax = 6f,
			Color = BloodColor,
		};

		GetParent().AddChild(particles);
		particles.GlobalPosition = at;   // set after it's in the tree
		particles.Emitting = true;

		GetTree().CreateTimer(particles.Lifetime + 0.2).Timeout += particles.QueueFree;
	}

	private void PaintStreaks(Node2D offender, Vector2 hitPos, Vector2 dir)
	{
		// Paint onto the rectangle's visual if it has one, so it can clip the streaks.
		Node2D canvas = offender.GetNodeOrNull<Node2D>("Visual") ?? offender;
		if (canvas != offender)
			canvas.ClipChildren = ClipChildrenMode.AndDraw;

		var taper = new Curve();
		taper.AddPoint(new Vector2(0, 1f));
		taper.AddPoint(new Vector2(1, 0.15f));

		for (int i = 0; i < StreakCount; i++)
		{
			Vector2 globalDir = dir.Rotated(_rng.RandfRange(-0.9f, 0.9f));
			float length = _rng.RandfRange(20f, 80f);

			Vector2 start = hitPos;
			Vector2 mid = hitPos + globalDir * length * 0.5f
						  + globalDir.Orthogonal() * _rng.RandfRange(-6f, 6f);
			Vector2 end = hitPos + globalDir * length;

			var line = new Line2D
			{
				Width = _rng.RandfRange(3f, 9f),
				WidthCurve = taper,
				DefaultColor = BloodColor with { A = _rng.RandfRange(0.75f, 0.95f) },
				BeginCapMode = Line2D.LineCapMode.Round,
				EndCapMode = Line2D.LineCapMode.Round,
			};

			// Convert to the body's local space so the streaks move and rotate with it.
			line.AddPoint(canvas.ToLocal(start));
			line.AddPoint(canvas.ToLocal(mid));
			line.AddPoint(canvas.ToLocal(end));

			canvas.AddChild(line);
		}
	}
}
