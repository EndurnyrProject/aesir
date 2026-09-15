defmodule Aesir.ZoneServer.Content.Npc.Cities.Jawaii.Employee3094 do
  @moduledoc """
  Welcomes married and unmarried patrons to the Jawaii Tavern as Employee Tonia.

  ## Behavior

  - Responds to welcome and solo events with different emotions.

  ## Credits

  - Original from rAthena, authors and Contributors
    - jAthena
    - DNett123
    - L0ne_w0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "jawaii_in",
        x: 30,
        y: 94,
        dir: 4,
        sprite: 724,
        name: "Employee",
        scope: :shared,
        unique_name: "Employee#jaw5"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnWelcome", ctx), do: emotion(ctx, :chup)
  def on_event("OnSolo", ctx), do: emotion(ctx, :huk)

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = ctx |> mes("[Employee Tonia]") |> mes("Welcome to Jawaii Tavern~")

    partner_id = getpartnerid(ctx)

    cond do
      Rathena.truthy?(partner_id) -> married_dialogue(ctx)
      not Rathena.truthy?(partner_id) -> single_dialogue(ctx)
      true -> ctx |> mes("I hope you will have a good time.") |> close()
    end
  end

  defp married_dialogue(ctx) do
    ctx
    |> next()
    |> mes("[Employee Tonia]")
    |> mes("Congratulations to both of you!")
    |> next()
    |> mes("[Employee Tonia]")
    |> mes("^666666*Sigh...*^000000")
    |> mes(
      "^333333I hope those Single Army morons don't get drunk and do something stupid again..."
    )
    |> close()
  end

  defp single_dialogue(ctx) do
    ctx
    |> mes("Wait a sec. You're...!")
    |> next()
    |> mes("[Employee Tonia]")
    |> mes("Hey--!")
    |> mes("You're not welcome here!")
    |> mes("S-Stop drinking! Right this instant!")
    |> close()
  end
end
