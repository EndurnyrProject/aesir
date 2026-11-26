defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.EmEnd do
  @moduledoc """
  A timed announcement broadcasts the Pope’s speech in Rachel.

  ## Behavior

  - Starts the speech when an eligible player enters, and resets after the announcement.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Koca
    - Yommy
    - brianluau
    - Euphy
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "rachel",
        x: 142,
        y: 136,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#em_end",
        trigger: {5, 5}
      }
    ]

  @impl true
  def on_event("OnInit", ctx), do: ev_oninit(ctx)
  def on_event("OnTouch_", ctx), do: ev_ontouch(ctx)
  def on_event("OnTimer4000", ctx), do: ev_ontimer4000(ctx)
  def on_event("OnTimer7000", ctx), do: ev_ontimer7000(ctx)
  def on_event("OnTimer10000", ctx), do: ev_ontimer10000(ctx)
  def on_event("OnTimer15000", ctx), do: ev_ontimer15000(ctx)
  def on_event("OnTimer19000", ctx), do: ev_ontimer19000(ctx)
  def on_event("OnTimer23000", ctx), do: ev_ontimer23000(ctx)
  def on_event("OnTimer30000", ctx), do: ev_ontimer30000(ctx)
  def on_event("OnTimer35000", ctx), do: ev_ontimer35000(ctx)
  def on_event("OnTimer43000", ctx), do: ev_ontimer43000(ctx)
  def on_event("OnTimer47000", ctx), do: ev_ontimer47000(ctx)
  def on_event("OnTimer53000", ctx), do: ev_ontimer53000(ctx)
  @impl true
  def on_talk(ctx) do
    ev_oninit(ctx)
  end

  def ev_oninit(ctx) do
    stopnpctimer(ctx)
  end

  def ev_ontouch(ctx) do
    if get_char_var(ctx, :aru_em, 0) == 22 do
      ctx |> initnpctimer() |> disablenpc("#em_end")
    else
      ctx
    end
  end

  def ev_ontimer4000(ctx) do
    mapannounce(
      ctx,
      "rachel",
      "Pope: Citizens of Arunafeltz. High Priests and Priestesses.",
      1,
      "0xFFCE00"
    )
  end

  def ev_ontimer7000(ctx) do
    mapannounce(
      ctx,
      "rachel",
      "Pope: I appreciate you all for coming to the Sky Garden as I've asked.",
      1,
      "0xFFCE00"
    )
  end

  def ev_ontimer10000(ctx) do
    mapannounce(
      ctx,
      "rachel",
      "Pope: As the chosen vessel of Goddess Freya, I hereby announce the words I received from her yesterday.",
      1,
      "0xFFCE00"
    )
  end

  def ev_ontimer15000(ctx) do
    mapannounce(
      ctx,
      "rachel",
      "Pope: I have observed all that is happening in Arunafeltz.",
      1,
      "0x66CCCC"
    )
  end

  def ev_ontimer19000(ctx) do
    mapannounce(
      ctx,
      "rachel",
      "Pope: I am aware of the factioning between the High Priests, their selfish fighting, their failure to achieve solidarity.",
      1,
      "0x66CCCC"
    )
  end

  def ev_ontimer23000(ctx) do
    mapannounce(
      ctx,
      "rachel",
      "Pope: However, I did not intervene for the sake of those that still pray for peace in Arunafeltz.",
      1,
      "0x66CCCC"
    )
  end

  def ev_ontimer30000(ctx) do
    mapannounce(
      ctx,
      "rachel",
      "Pope: High Priest Zhed and High Priestess Niren, both of you must do your best to assist my vessel until the day of my arrival.",
      1,
      "0x66CCCC"
    )
  end

  def ev_ontimer35000(ctx) do
    mapannounce(
      ctx,
      "rachel",
      "Pope: As for the other high priests, you have forgotten your duty to serve me, to enlighten my followers with my teachings. For pursuing your selfish desires, you will be all under Zhed and Niren's command.",
      1,
      "0x66CCCC"
    )
  end

  def ev_ontimer43000(ctx) do
    mapannounce(
      ctx,
      "rachel",
      "Pope: My followers in Arunafeltz, keep your faith in me, and keep your country strong.",
      1,
      "0x66CCCC"
    )
  end

  def ev_ontimer47000(ctx) do
    mapannounce(ctx, "rachel", "Pope: Then, paradise will surely be yours.", 1, "0x66CCCC")
  end

  def ev_ontimer53000(ctx) do
    ctx
    |> mapannounce("rachel", "Citizens: Hail Freya! Hail to the Pope!", 1, "0x99CC00")
    |> stopnpctimer()
    |> enablenpc("#em_end")
  end
end
