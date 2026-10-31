//! The selected instance's views (plan R0, screen 5): Overview (what Play needs), then its mods,
//! worlds, servers, packs, screenshots and, once the game has said something, its console. One at a
//! time, in the pane's strip above the content rather than as one long page.
use super::*;

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub(super) enum HomeTab {
    #[default]
    Overview,
    Mods,
    Worlds,
    Multiplayer,
    Packs,
    Screenshots,
    Console,
}

impl HomeTab {
    /// `HORIZON_LAUNCHER_PAGE=worlds` (or `instance-mods`, `multiplayer`, `packs`, `screenshots`,
    /// `console`) opens Home on that tab, for screenshots.
    pub(super) fn from_env() -> Self {
        match std::env::var("HORIZON_LAUNCHER_PAGE").as_deref() {
            Ok("instance-mods") => HomeTab::Mods,
            Ok("worlds") => HomeTab::Worlds,
            Ok("multiplayer") => HomeTab::Multiplayer,
            Ok("packs") => HomeTab::Packs,
            Ok("screenshots") => HomeTab::Screenshots,
            Ok("console") => HomeTab::Console,
            _ => HomeTab::Overview,
        }
    }

    /// Its name in the strip.
    pub(super) fn label(self) -> &'static str {
        match self {
            HomeTab::Overview => tr("Overview"),
            HomeTab::Mods => tr("Mods"),
            HomeTab::Worlds => tr("Worlds"),
            HomeTab::Multiplayer => tr("Multiplayer"),
            HomeTab::Packs => tr("Packs"),
            HomeTab::Screenshots => tr("Screenshots"),
            HomeTab::Console => tr("Console"),
        }
    }
}

impl Launcher {
    /// The tabs the selected instance has now, with how many things each holds (None: not known
    /// yet, or nothing to count). Screenshots and Console only once there is something to show.
    pub(super) fn home_tab_list(
        &mut self,
        cx: &mut Context<Self>,
    ) -> Vec<(HomeTab, Option<usize>)> {
        let mut tabs = vec![(HomeTab::Overview, None)];
        if self.selected_instance().is_none() {
            return tabs;
        }
        if self.has_mods_tab() {
            tabs.push((HomeTab::Mods, self.instance_mods_count(cx)));
        }
        tabs.push((HomeTab::Worlds, self.worlds_count(cx)));
        tabs.push((HomeTab::Multiplayer, Some(self.servers_count())));
        tabs.push((HomeTab::Packs, Some(self.packs_count())));
        let shots = self.screenshots_count();
        if shots > 0 {
            tabs.push((HomeTab::Screenshots, Some(shots)));
        }
        if !self.prepare_log.is_empty() || self.client.is_some() {
            tabs.push((HomeTab::Console, None));
        }
        tabs
    }

    /// The open tab's content, under the pane's strip: `overview` is what Play needs (Home's rows).
    /// The tab's own buttons sit above it, on the right, as a list's header would.
    pub(super) fn home_body(&mut self, overview: Div, cx: &mut Context<Self>) -> Div {
        let tabs = self.home_tab_list(cx);
        // A tab that went away (no screenshots left, another instance) falls back to Overview.
        let open = tabs
            .iter()
            .map(|(tab, _)| *tab)
            .find(|tab| *tab == self.home_tab)
            .unwrap_or(HomeTab::Overview);
        let (actions, body) = match open {
            HomeTab::Overview => (None, Some(overview.into_any_element())),
            HomeTab::Mods => {
                let (actions, body) = split(self.instance_mods_tab(cx));
                (Some(actions), Some(body))
            }
            HomeTab::Worlds => (
                None,
                self.worlds_section(cx).map(IntoElement::into_any_element),
            ),
            HomeTab::Multiplayer => self.multiplayer_section(cx).map(split).unzip(),
            HomeTab::Packs => self.packs_section(cx).map(split).unzip(),
            HomeTab::Screenshots => self.screenshots_section(cx).map(split).unzip(),
            HomeTab::Console => self.console_section(cx).map(split).unzip(),
        };
        div()
            .flex()
            .flex_col()
            .gap(px(14.))
            .children(actions.flatten().map(|actions| {
                div()
                    .flex()
                    .flex_wrap()
                    .justify_end()
                    .child(actions)
                    .into_any_element()
            }))
            .children(body)
    }
}

/// A tab's buttons and content, as the strip and the page take them.
fn split(tab: (Div, impl IntoElement)) -> (Option<Div>, AnyElement) {
    (Some(tab.0), tab.1.into_any_element())
}
