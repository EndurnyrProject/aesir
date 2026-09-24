defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Rogue.HeToRogue do
  @moduledoc """
  Guards the locked door to the Rogue job test tunnel with a four-number combination.

  ## Behavior

  - Asks for the combination when a player steps up to the door.
  - Opens the door and moves candidates sent by Hermanthorn Jr. into the tunnel on the right
    combination.
  - Rejects out-of-range or wrong combinations, and teases players who know the combination but
    were not sent by Hermanthorn Jr.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Samuray22
    - Brainstorm
    - Kisuka

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "in_rogue",
        x: 270,
        y: 130,
        dir: 0,
        sprite: 45,
        name: "he_to_rogue",
        scope: :shared,
        unique_name: "he_to_rogue#rg",
        trigger: {1, 1}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @combination 3019

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx) do
    {ctx, combination} =
      ctx
      |> mes(
        "^3355FFThe door is locked. You'll need to enter the four number combination to open it.^000000"
      )
      |> next()
      |> input(:int)

    cond do
      combination < 1 or combination > 10_000 -> reject_combination(ctx)
      combination == @combination -> try_open(ctx)
      true -> ctx |> mes("^3355FFThe door") |> mes("is still locked.^000000") |> close()
    end
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  defp reject_combination(ctx) do
    ctx =
      if get_char_var(ctx, :ROGUE_Q, 0) == 12 do
        mes(ctx, "^3355FFIt didn't work. Please re-enter the four number combination.^000000")
      else
        mes(ctx, "^3355FFPlease enter a combination of four numbers.^000000")
      end

    close(ctx)
  end

  defp try_open(ctx) do
    if get_char_var(ctx, :ROGUE_Q, 0) == 12 do
      ctx
      |> mes("^3355FFThe door")
      |> mes("has opened.^000000")
      |> close()
      |> warp("in_rogue", 10, 21)
      |> set_char_var(:ROGUE_Q, 12)
    else
      ctx
      |> mes("[HermanthornJr.]")
      |> mes("Well...")
      |> mes("Didn't I tell you")
      |> mes("that I changed the")
      |> mes("password? *Wink Wink*")
      |> close()
    end
  end
end
